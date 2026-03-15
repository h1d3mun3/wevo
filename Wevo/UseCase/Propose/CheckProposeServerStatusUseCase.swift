//
//  CheckProposeServerStatusUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

/// Server status check result (new API specification)
struct ProposeServerCheckResult {
    /// Status returned by the server
    let serverStatus: ProposeStatus
    /// Signature string when the Counterparty has signed on the server but it has not yet been reflected locally (nil means no new signature)
    let pendingCounterpartySignSignature: String?
    /// Terminal status (honored/parted/dissolved) that the server has reached but has not yet been reflected locally (nil means no pending transition)
    let pendingStatusTransition: ProposeStatus?
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
        let hashedPropose = try await client.getPropose(proposeID: propose.id)

        print("📊 Server status: \(hashedPropose.status.rawValue)")

        // Check if the Counterparty has signed on the server but it has not yet been reflected locally (PoC has only 1 counterparty)
        var pendingSignSignature: String? = nil
        if let counterparty = hashedPropose.counterparties.first(where: { $0.publicKey == propose.counterpartyPublicKey }),
           let serverSignSignature = counterparty.signSignature,
           propose.counterpartySignSignature == nil {
            pendingSignSignature = serverSignSignature
            print("🔄 Detected Counterparty signature from server: not yet reflected locally")
        }

        // Check if the server has reached a terminal state (honored/parted/dissolved) not yet reflected locally
        var pendingStatusTransition: ProposeStatus? = nil
        let terminalStatuses: Set<ProposeStatus> = [.honored, .parted, .dissolved]
        if terminalStatuses.contains(hashedPropose.status),
           propose.localStatus != hashedPropose.status {
            pendingStatusTransition = hashedPropose.status
            print("🔄 Detected terminal status from server: \(hashedPropose.status.rawValue), not yet reflected locally")
        }

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
            pendingCounterpartySignSignature: pendingSignSignature,
            pendingStatusTransition: pendingStatusTransition,
            myHonorSigned: myHonorSigned,
            myPartSigned: myPartSigned
        )
    }
}
