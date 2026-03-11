//
//  Untitled.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

enum SignProposeUseCaseError: Error {
    case failedToSavePropose
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

        // ペイロードハッシュに署名
        let signatureData = try keychainRepository.signMessage(
            propose.payloadHash,
            withIdentityId: identity.id,
            context: nil
        )

        // 新しいSignatureを作成
        let newSignature = Signature(
            id: UUID(),
            publicKey: identity.publicKey,
            signature: signatureData,
            createdAt: Date()
        )

        // Proposeに署名を追加
        var updatedSignatures = propose.signatures
        updatedSignatures.append(newSignature)

        let updatedPropose = Propose(
            id: propose.id,
            spaceID: propose.spaceID,
            message: propose.message,
            signatures: updatedSignatures,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )

        // ローカルに保存
        do {
            try proposeRepository.update(updatedPropose)
            print("✅ Signature added locally: \(propose.id)")
        } catch {
            print("❌ Failed to update propose locally: \(error)")

            throw SignProposeUseCaseError.failedToSavePropose
        }
    }
}
