//
//  AppendServerSignaturesToLocalProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol AppendServerSignaturesToLocalProposeUseCase {
    func execute(proposeID: UUID, with serverSignatures: [Signature]) throws
}

struct AppendServerSignaturesToLocalProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension AppendServerSignaturesToLocalProposeUseCaseImpl: AppendServerSignaturesToLocalProposeUseCase {
    func execute(proposeID: UUID, with serverSignatures: [Signature]) throws {
        let localPropose = try proposeRepository.fetch(by: proposeID)

        // サーバーから取得した署名をローカルのProposeに追加
        var updatedSignatures = localPropose.signatures
        updatedSignatures.append(contentsOf: serverSignatures)

        let updatedPropose = Propose(
            id: localPropose.id,
            message: localPropose.message,
            signatures: updatedSignatures,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        // ローカルに保存
        try proposeRepository.update(updatedPropose)
        print("✅ Synced \(serverSignatures.count) new signature(s) from server: \(localPropose.id)")
    }
}
