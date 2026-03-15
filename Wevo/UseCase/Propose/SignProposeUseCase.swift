//
//  SignProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

enum SignProposeUseCaseError: Error {
    case failedToSavePropose
    /// 署名しようとしているIDがCounterpartyではない
    case notCounterparty
}

protocol SignProposeUseCase {
    func execute(to proposeID: UUID, signIdentityID: UUID) async throws
}

struct SignProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let proposeRepository: ProposeRepository

    init(keychainRepository: KeychainRepository, proposeRepository: ProposeRepository) {
        self.keychainRepository = keychainRepository
        self.proposeRepository = proposeRepository
    }
}

extension SignProposeUseCaseImpl: SignProposeUseCase {
    func execute(to proposeID: UUID, signIdentityID: UUID) async throws {
        let identity = try keychainRepository.getIdentity(id: signIdentityID)
        let propose = try proposeRepository.fetch(by: proposeID)

        // CounterpartyのみがSignできる
        guard identity.publicKey == propose.counterpartyPublicKey else {
            print("⚠️ 署名者がCounterpartyではありません: \(identity.publicKey)")
            throw SignProposeUseCaseError.notCounterparty
        }

        // 署名メッセージを構築（sign: proposeId + contentHash + signerPublicKey + ISO8601(propose.createdAt)）
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)
        let signatureMessage = propose.id.uuidString + propose.payloadHash + identity.publicKey + iso8601String

        // 署名
        let signatureData = try keychainRepository.signMessage(
            signatureMessage,
            withIdentityId: identity.id
        )

        // counterpartySignSignatureをセットしてProposeを更新
        let updatedPropose = Propose(
            id: propose.id,
            spaceID: propose.spaceID,
            message: propose.message,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKey: propose.counterpartyPublicKey,
            counterpartySignSignature: signatureData,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )

        // ローカルに保存
        do {
            try proposeRepository.update(updatedPropose)
            print("✅ Counterparty署名をローカルに保存しました: \(propose.id)")
        } catch {
            print("❌ Proposeの更新に失敗しました: \(error)")
            throw SignProposeUseCaseError.failedToSavePropose
        }

        // APIに送信（失敗してもローカルには保存済みなので警告のみ）
        // APIへの送信は SendLocalSignaturesToServerUseCase で行う
        print("ℹ️ API送信はSendLocalSignaturesToServerUseCaseで実行してください")
    }
}
