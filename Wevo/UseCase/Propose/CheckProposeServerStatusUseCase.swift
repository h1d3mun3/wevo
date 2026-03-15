//
//  CheckProposeServerStatusUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

/// サーバーステータス確認結果（新API仕様）
struct ProposeServerCheckResult {
    /// サーバーが返したステータス
    let serverStatus: ProposeStatus
    /// Counterpartyがサーバーで署名済みだがローカル未反映の場合の署名文字列（nilの場合は新着なし）
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

        print("📊 サーバーステータス: \(hashedPropose.status.rawValue)")

        // Counterpartyがサーバーで署名済みかつローカル未反映かを確認（PoCは1名のみ）
        var pendingSignSignature: String? = nil
        if let counterparty = hashedPropose.counterparties.first(where: { $0.publicKey == propose.counterpartyPublicKey }),
           let serverSignSignature = counterparty.signSignature,
           propose.counterpartySignSignature == nil {
            // サーバーでは署名済みだがローカルにはまだ反映されていない
            pendingSignSignature = serverSignSignature
            print("🔄 Counterpartyの署名をサーバーから検出: ローカル未反映")
        }

        return ProposeServerCheckResult(
            serverStatus: hashedPropose.status,
            pendingCounterpartySignSignature: pendingSignSignature
        )
    }
}
