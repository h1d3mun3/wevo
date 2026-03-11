//
//  CheckProposeServerStatusUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

struct ProposeServerStatus {
    let exists: Bool
    let newServerSignatures: [Signature]
    let localOnlySignatures: [Signature]
}

protocol CheckProposeServerStatusUseCase {
    func execute(propose: Propose, serverURL: String) async throws -> ProposeServerStatus
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
    func execute(propose: Propose, serverURL: String) async throws -> ProposeServerStatus {
        guard let baseURL = URL(string: serverURL) else {
            throw CheckProposeServerStatusUseCaseError.invalidServerURL
        }

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        let hashedPropose = try await client.getPropose(proposeID: propose.id)

        print("📊 Server has \(hashedPropose.signatures.count) signatures, local has \(propose.signatures.count)")

        // 署名の公開鍵で比較するためのセット
        let localPublicKeys = Set(propose.signatures.map { $0.publicKey })
        let serverPublicKeys = Set(hashedPropose.signatures.map { $0.publicKey })

        // サーバーにのみある署名を抽出（ローカルにない新しい署名）
        let newServerSignatures = hashedPropose.signatures.compactMap { signInput -> Signature? in
            guard !localPublicKeys.contains(signInput.publicKey) else { return nil }
            return Signature(
                id: signInput.id,
                publicKey: signInput.publicKey,
                signature: signInput.signature,
                createdAt: signInput.createdAt
            )
        }

        // ローカルにのみある署名を抽出（サーバーにまだ送られていない署名）
        let localOnlySigs = propose.signatures.filter { signature in
            !serverPublicKeys.contains(signature.publicKey)
        }

        if !newServerSignatures.isEmpty {
            print("🔄 Found \(newServerSignatures.count) new signature(s) on server")
        }
        if !localOnlySigs.isEmpty {
            print("📤 Found \(localOnlySigs.count) local-only signature(s)")
        }

        return ProposeServerStatus(
            exists: true,
            newServerSignatures: newServerSignatures,
            localOnlySignatures: localOnlySigs
        )
    }
}
