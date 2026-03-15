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
}

protocol CheckProposeServerStatusUseCase {
    func execute(propose: Propose, serverURL: String) async throws -> ProposeServerCheckResult
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
    func execute(propose: Propose, serverURL: String) async throws -> ProposeServerCheckResult {
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
            // Signed on server but not yet reflected locally
            pendingSignSignature = serverSignSignature
            print("🔄 Detected Counterparty signature from server: not yet reflected locally")
        }

        return ProposeServerCheckResult(
            serverStatus: hashedPropose.status,
            pendingCounterpartySignSignature: pendingSignSignature
        )
    }
}
