//
//  CreateProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import CryptoKit

protocol CreateProposeUseCase {
    func execute(identityID: UUID, spaceID: UUID, message: String, counterpartyPublicKey: String) async throws
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
    func execute(identityID: UUID, spaceID: UUID, message: String, counterpartyPublicKey: String) async throws {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let identity = try keychainRepository.getIdentity(id: identityID)
        let space = try spaceRepository.fetch(by: spaceID)

        // ProposeIDと作成日時を生成
        let proposeID = UUID()
        let createdAt = Date()

        // contentHash（SHA256）を計算
        let contentHash = trimmedMessage.sha256HashedString

        // 署名メッセージを構築（create: proposeId + contentHash + counterpartyPublicKeys(sorted & joined) + createdAt）
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: createdAt)
        let sortedCounterpartyKeys = [counterpartyPublicKey].sorted().joined()
        let signatureMessage = proposeID.uuidString + contentHash + sortedCounterpartyKeys + iso8601String

        // Creatorが署名
        let creatorSignature = try keychainRepository.signMessage(
            signatureMessage,
            withIdentityId: identity.id
        )

        // Proposeエンティティを作成（counterpartySignSignatureはnilで初期化）
        let propose = Propose(
            id: proposeID,
            spaceID: spaceID,
            message: trimmedMessage,
            creatorPublicKey: identity.publicKey,
            creatorSignature: creatorSignature,
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        // ローカルに保存
        try proposeRepository.create(propose, spaceID: space.id)
        print("✅ Proposeをローカルに保存しました: \(proposeID)")
        print("   メッセージ: \(trimmedMessage)")
        print("   contentHash: \(contentHash)")

        // APIに送信（失敗してもローカルには保存済みなので警告のみ）
        guard let baseURL = URL(string: space.url) else {
            print("⚠️ 無効なサーバーURL: \(space.url)")
            return
        }

        let input = ProposeAPIClient.CreateProposeInput(
            proposeId: proposeID.uuidString,
            contentHash: contentHash,
            creatorPublicKey: identity.publicKey,
            creatorSignature: creatorSignature,
            counterpartyPublicKeys: [counterpartyPublicKey],
            createdAt: iso8601String
        )

        do {
            let client = ProposeAPIClient(baseURL: baseURL)
            try await client.createPropose(input: input)
            print("✅ ProposeをAPIに送信しました: \(proposeID)")
        } catch {
            // API送信に失敗してもローカルには保存済みなので警告のみ
            print("⚠️ APIへの送信に失敗しました（ローカルには保存済み）: \(error)")
        }
    }
}
