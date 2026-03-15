//
//  AppendServerSignaturesToLocalProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol AppendServerSignaturesToLocalProposeUseCase {
    /// Counterpartyのsign署名をローカルのProposeに反映する
    /// - Parameters:
    ///   - proposeID: 対象ProposeのID
    ///   - counterpartySignSignature: Counterpartyの署名文字列（Base64 DER）
    func execute(proposeID: UUID, counterpartySignSignature: String) throws
}

struct AppendServerSignaturesToLocalProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension AppendServerSignaturesToLocalProposeUseCaseImpl: AppendServerSignaturesToLocalProposeUseCase {
    func execute(proposeID: UUID, counterpartySignSignature: String) throws {
        let localPropose = try proposeRepository.fetch(by: proposeID)

        // counterpartySignSignatureをセットしてProposeを更新
        let updatedPropose = Propose(
            id: localPropose.id,
            spaceID: localPropose.spaceID,
            message: localPropose.message,
            creatorPublicKey: localPropose.creatorPublicKey,
            creatorSignature: localPropose.creatorSignature,
            counterpartyPublicKey: localPropose.counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        // ローカルに保存
        try proposeRepository.update(updatedPropose)
        print("✅ Counterparty署名をローカルに反映しました: \(localPropose.id)")
    }
}
