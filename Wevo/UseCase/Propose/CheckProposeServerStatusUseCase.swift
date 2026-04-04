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
}

protocol CheckProposeServerStatusUseCase {
    func execute(propose: Propose, serverURL: String, myPublicKey: String?) async throws -> ProposeServerCheckResult
}

enum CheckProposeServerStatusUseCaseError: Error {
    case invalidServerURL
    case proposeNotFound
}

struct CheckProposeServerStatusUseCaseImpl {
    let apiClient: ProposeAPIClientProtocol?

    init(apiClient: ProposeAPIClientProtocol? = nil) {
        self.apiClient = apiClient
    }
}

extension CheckProposeServerStatusUseCaseImpl: CheckProposeServerStatusUseCase {
    func execute(propose: Propose, serverURL: String, myPublicKey: String? = nil) async throws -> ProposeServerCheckResult {
        guard let baseURL = URL(string: serverURL) else {
            throw CheckProposeServerStatusUseCaseError.invalidServerURL
        }

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
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

        // Check if the Counterparty has signed on the server but it has not yet been reflected locally (PoC has only 1 counterparty)
        var hasPendingCounterpartySignature = false
        if let counterparty = hashedPropose.counterparties.first(where: { $0.publicKey == propose.counterpartyPublicKey }),
           counterparty.signSignature != nil,
           propose.counterpartySignSignature == nil {
            hasPendingCounterpartySignature = true
            Logger.propose.info("Detected Counterparty signature from server: not yet reflected locally")
        }

        // Check if the server has reached a terminal state (honored/parted/dissolved) not yet reflected locally
        var hasPendingTerminalStatus = false
        let terminalStatuses: Set<ProposeStatus> = [.honored, .parted, .dissolved]
        if terminalStatuses.contains(hashedPropose.status),
           propose.localStatus != hashedPropose.status {
            hasPendingTerminalStatus = true
            Logger.propose.info("Detected terminal status from server: \(hashedPropose.status.rawValue, privacy: .public), not yet reflected locally")
        }

        let pendingServerUpdate: HashedPropose? = (hasPendingCounterpartySignature || hasPendingTerminalStatus) ? hashedPropose : nil

        // Check if the current user has already sent their honor/part signature
        var myHonorSigned = false
        var myPartSigned = false
        if let myPublicKey = myPublicKey {
            if myPublicKey == propose.creatorPublicKey {
                myHonorSigned = hashedPropose.honorCreatorSignature != nil
                myPartSigned = hashedPropose.partCreatorSignature != nil
            } else if let counterparty = hashedPropose.counterparties.first(where: { $0.publicKey == myPublicKey }) {
                myHonorSigned = counterparty.honorSignature != nil
                myPartSigned = counterparty.partSignature != nil
            }
        }

        return ProposeServerCheckResult(
            serverStatus: hashedPropose.status,
            pendingServerUpdate: pendingServerUpdate,
            myHonorSigned: myHonorSigned,
            myPartSigned: myPartSigned
        )
    }
}
