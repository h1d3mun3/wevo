//
//  CheckProposeServerStatusUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

/// Server status check result (new API specification)
struct ProposeServerCheckResult {
    /// Status returned by the server
    let serverStatus: ProposeStatus
    /// Full server HashedPropose when there are server-side changes not yet reflected locally
    /// (counterparty signed on server, or server reached a terminal state not yet reflected locally)
    let pendingServerUpdate: HashedPropose?
    /// Whether the current user has already sent their honor signature to the server
    let myHonorSigned: Bool
    /// Whether the current user has already sent their part signature to the server
    let myPartSigned: Bool
    /// Whether the local Propose has a signature from the current user that has not yet reached the server
    let pendingLocalResend: Bool
}

protocol CheckProposeServerStatusUseCase {
    func execute(propose: Propose, serverURLs: [String], myPublicKey: String?) async throws -> ProposeServerCheckResult
}

enum CheckProposeServerStatusUseCaseError: Error {
    case invalidServerURL
    case proposeNotFound
}

struct CheckProposeServerStatusUseCaseImpl {
    let keychainRepository: KeychainRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.apiClient = apiClient
    }
}

extension CheckProposeServerStatusUseCaseImpl: CheckProposeServerStatusUseCase {
    func execute(propose: Propose, serverURLs: [String], myPublicKey: String? = nil) async throws -> ProposeServerCheckResult {
        guard !serverURLs.isEmpty else {
            throw CheckProposeServerStatusUseCaseError.invalidServerURL
        }

        let client = apiClient ?? ResilientProposeAPIClient(urls: serverURLs)
        let hashedPropose: HashedPropose
        do {
            hashedPropose = try await client.getPropose(proposeID: propose.id)
        } catch let error as ProposeAPIClient.APIError {
            if case .httpError(let statusCode) = error, statusCode == 404 {
                throw CheckProposeServerStatusUseCaseError.proposeNotFound
            }
            throw error
        }

        Logger.propose.debug("Server status: \(hashedPropose.status.rawValue, privacy: .public)")

        // Verify a server-provided signature against the LOCAL participant key before trusting any
        // "server has an update" signal — so a hostile server/MITM cannot drive the UI with forged
        // signatures or a fabricated terminal state. (v1: "<verb>." + id + hash + signerKey + ts)
        let proposeIDString = propose.id.uuidString
        let payloadHash = propose.payloadHash
        func verify(_ sig: String?, _ ts: String?, _ signerKey: String, _ verb: String) -> Bool {
            guard let sig, let ts else { return false }
            let message = verb + "." + proposeIDString + payloadHash + signerKey + ts
            return (try? keychainRepository.verifySignature(sig, for: message, withPublicKeyString: signerKey)) == true
        }

        // Check if the Counterparty has signed on the server but it has not yet been reflected locally (PoC has only 1 counterparty)
        var hasPendingCounterpartySignature = false
        if let counterparty = hashedPropose.counterparties.first(where: { $0.publicKey == propose.counterpartyPublicKey }),
           counterparty.signSignature != nil,
           propose.counterpartySignSignature == nil,
           verify(counterparty.signSignature, counterparty.signTimestamp, propose.counterpartyPublicKey, "signed") {
            hasPendingCounterpartySignature = true
            Logger.propose.info("Detected Counterparty signature from server: not yet reflected locally")
        }

        // Check if the server has reached a terminal state (honored/parted/dissolved) not yet
        // reflected locally. The prompt this drives leads to acceptServerPropose →
        // MergeServerSignatures, which verifies every adopted signature, so a forged terminal
        // status cannot corrupt local state even though the prompt itself is not gated here.
        var hasPendingTerminalStatus = false
        let terminalStatuses: Set<ProposeStatus> = [.honored, .parted, .dissolved]
        if terminalStatuses.contains(hashedPropose.status),
           propose.localStatus != hashedPropose.status {
            hasPendingTerminalStatus = true
            Logger.propose.info("Detected terminal status from server: \(hashedPropose.status.rawValue, privacy: .public), not yet reflected locally")
        }

        let pendingServerUpdate: HashedPropose? = (hasPendingCounterpartySignature || hasPendingTerminalStatus) ? hashedPropose : nil

        // Check if the current user has already sent their honor/part signature
        // Also detect if the local Propose has signatures not yet on the server
        var myHonorSigned = false
        var myPartSigned = false
        var pendingLocalResend = false
        if let myPublicKey = myPublicKey {
            if myPublicKey == propose.creatorPublicKey {
                myHonorSigned = hashedPropose.honorCreatorSignature != nil
                myPartSigned = hashedPropose.partCreatorSignature != nil
                if propose.creatorHonorSignature != nil && hashedPropose.honorCreatorSignature == nil {
                    pendingLocalResend = true
                }
                if propose.creatorPartSignature != nil && hashedPropose.partCreatorSignature == nil {
                    pendingLocalResend = true
                }
                if propose.creatorDissolveSignature != nil && hashedPropose.creatorDissolveSignature == nil {
                    pendingLocalResend = true
                }
            } else if let counterparty = hashedPropose.counterparties.first(where: { $0.publicKey == myPublicKey }) {
                myHonorSigned = counterparty.honorSignature != nil
                myPartSigned = counterparty.partSignature != nil
                if propose.counterpartySignSignature != nil && counterparty.signSignature == nil {
                    pendingLocalResend = true
                }
                if propose.counterpartyHonorSignature != nil && counterparty.honorSignature == nil {
                    pendingLocalResend = true
                }
                if propose.counterpartyPartSignature != nil && counterparty.partSignature == nil {
                    pendingLocalResend = true
                }
                if propose.counterpartyDissolveSignature != nil && counterparty.dissolveSignature == nil {
                    pendingLocalResend = true
                }
            }
        }

        return ProposeServerCheckResult(
            serverStatus: hashedPropose.status,
            pendingServerUpdate: pendingServerUpdate,
            myHonorSigned: myHonorSigned,
            myPartSigned: myPartSigned,
            pendingLocalResend: pendingLocalResend
        )
    }
}
