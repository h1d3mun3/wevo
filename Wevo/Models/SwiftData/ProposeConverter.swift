//
//  ProposeConverter.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// Propose構造体とProposeSwiftDataの相互変換を行う
struct ProposeConverter {

    /// Propose構造体からProposeSwiftDataへ変換
    static func toModel(from propose: Propose, spaceID: UUID) -> ProposeSwiftData {
        return ProposeSwiftData(
            id: propose.id,
            message: propose.message,
            payloadHash: propose.payloadHash,
            spaceID: spaceID,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKey: propose.counterpartyPublicKey,
            counterpartySignSignature: propose.counterpartySignSignature,
            createdAt: propose.createdAt,
            updatedAt: propose.updatedAt
        )
    }

    /// ProposeSwiftDataからPropose構造体へ変換
    static func toEntity(from model: ProposeSwiftData) -> Propose {
        return Propose(
            id: model.id,
            spaceID: model.spaceID,
            message: model.message,
            creatorPublicKey: model.creatorPublicKey,
            creatorSignature: model.creatorSignature,
            counterpartyPublicKey: model.counterpartyPublicKey,
            counterpartySignSignature: model.counterpartySignSignature,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    /// 複数のProposeSwiftDataをPropose構造体のリストに変換
    static func toEntities(from models: [ProposeSwiftData]) -> [Propose] {
        return models.map { model in
            toEntity(from: model)
        }
    }

    /// ProposeSwiftDataを既存のPropose構造体で更新
    static func updateModel(_ model: ProposeSwiftData, with propose: Propose) {
        model.message = propose.message
        model.payloadHash = propose.payloadHash
        model.creatorPublicKey = propose.creatorPublicKey
        model.creatorSignature = propose.creatorSignature
        model.counterpartyPublicKey = propose.counterpartyPublicKey
        model.counterpartySignSignature = propose.counterpartySignSignature
        model.updatedAt = Date()

        print("📝 ProposeSwiftData更新完了: counterpartySignSignature=\(propose.counterpartySignSignature ?? "nil")")
    }
}
