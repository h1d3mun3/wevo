//
//  CreateProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import CryptoKit

protocol CreateProposeUseCase {
    func execute(identityID: UUID, spaceID: UUID, message: String) async throws
}

struct CreateProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let spaceRepository: SpaceRepository
    let proposeRepository: ProposeRepository

    init(keychainRepository: KeychainRepository, spaceRepository: SpaceRepository, proposeRepository: ProposeRepository) {
        self.keychainRepository = keychainRepository
        self.spaceRepository = spaceRepository
        self.proposeRepository = proposeRepository
    }
}

extension CreateProposeUseCaseImpl: CreateProposeUseCase {
    func execute(identityID: UUID, spaceID: UUID, message: String) async throws {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let identity = try keychainRepository.getIdentity(id: identityID)
        let space = try spaceRepository.fetch(by: spaceID)

        // ProposeIDを生成
        let proposeID = UUID()

        // メッセージからPropose作成（自動的にハッシュ化される）
        let propose = Propose(
            id: proposeID,
            spaceID: spaceID,
            message: message,
            signatures: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        // 署名を作成（ハッシュ化されたメッセージに対して署名）
        let signature = try keychainRepository.signMessage(
            propose.payloadHash,
            withIdentityId: identity.id,
            context: nil
        )

        // Signatureエンティティを作成
        let signatureEntity = Signature(
            id: UUID(),
            publicKey: identity.publicKey,
            signature: signature,
            createdAt: Date()
        )

        // Proposeに署名を追加
        let signedPropose = Propose(
            id: propose.id,
            spaceID: spaceID,
            message: propose.message,
            signatures: [signatureEntity],
            createdAt: Date(),
            updatedAt: Date()
        )

        try proposeRepository.create(signedPropose, spaceID: space.id)
        print("✅ Propose saved to SwiftData: \(proposeID)")
        print("   Message: \(trimmedMessage)")
        print("   Hash: \(propose.payloadHash)")

        // 2. その後、APIに送信（ハッシュのみ、失敗しても画面は閉じる）
        guard let baseURL = URL(string: space.url) else {
            print("⚠️ Invalid server URL: \(space.url)")
            return
        }

        // ProposeInputを作成（ハッシュのみ送信）
        let input = ProposeAPIClient.ProposeInput(
            id: proposeID,
            payloadHash: signedPropose.payloadHash,
            publicKey: identity.publicKey,
            signatures: [.init(publicKey: identity.publicKey, signature: signature)]
        )

        do {
            // APIクライアントで送信
            let client = ProposeAPIClient(baseURL: baseURL)
            try await client.createPropose(input: input)

            print("✅ Propose sent to API successfully: \(proposeID)")
            print("   Only hash sent: \(signedPropose.payloadHash)")
        } catch {
            // API送信に失敗してもローカルには保存済みなので警告のみ
            print("⚠️ Failed to send propose to API: \(error)")
            print("ℹ️ Propose is saved locally and can be synced later")
        }

    }
}
