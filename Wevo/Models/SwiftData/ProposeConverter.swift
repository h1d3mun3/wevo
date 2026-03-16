//
//  ProposeConverter.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// Handles bidirectional conversion between the Propose struct and ProposeSwiftData
struct ProposeConverter {

    /// Converts a Propose struct to ProposeSwiftData
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
            counterpartySignTimestamp: propose.counterpartySignTimestamp,
            finalStatus: propose.finalStatus?.rawValue,
            createdAt: propose.createdAt,
            updatedAt: propose.updatedAt
        )
    }

    /// Converts ProposeSwiftData to a Propose struct
    static func toEntity(from model: ProposeSwiftData) -> Propose {
        return Propose(
            id: model.id,
            spaceID: model.spaceID,
            message: model.message,
            creatorPublicKey: model.creatorPublicKey,
            creatorSignature: model.creatorSignature,
            counterpartyPublicKey: model.counterpartyPublicKey,
            counterpartySignSignature: model.counterpartySignSignature,
            counterpartySignTimestamp: model.counterpartySignTimestamp,
            finalStatus: model.finalStatus.flatMap { ProposeStatus(rawValue: $0) },
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    /// Converts multiple ProposeSwiftData objects to a list of Propose structs
    static func toEntities(from models: [ProposeSwiftData]) -> [Propose] {
        return models.map { model in
            toEntity(from: model)
        }
    }

    /// Updates a ProposeSwiftData with an existing Propose struct
    static func updateModel(_ model: ProposeSwiftData, with propose: Propose) {
        model.message = propose.message
        model.payloadHash = propose.payloadHash
        model.creatorPublicKey = propose.creatorPublicKey
        model.creatorSignature = propose.creatorSignature
        model.counterpartyPublicKey = propose.counterpartyPublicKey
        model.counterpartySignSignature = propose.counterpartySignSignature
        model.counterpartySignTimestamp = propose.counterpartySignTimestamp
        model.finalStatus = propose.finalStatus?.rawValue
        model.updatedAt = Date()

        print("📝 ProposeSwiftData update complete: counterpartySignSignature=\(propose.counterpartySignSignature ?? "nil"), finalStatus=\(propose.finalStatus?.rawValue ?? "nil")")
    }
}
