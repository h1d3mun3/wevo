//
//  ProposeConverter.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import os

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
            counterpartyHonorSignature: propose.counterpartyHonorSignature,
            counterpartyHonorTimestamp: propose.counterpartyHonorTimestamp,
            counterpartyPartSignature: propose.counterpartyPartSignature,
            counterpartyPartTimestamp: propose.counterpartyPartTimestamp,
            creatorHonorSignature: propose.creatorHonorSignature,
            creatorHonorTimestamp: propose.creatorHonorTimestamp,
            creatorPartSignature: propose.creatorPartSignature,
            creatorPartTimestamp: propose.creatorPartTimestamp,
            dissolvedAt: propose.dissolvedAt,
            creatorDissolveSignature: propose.creatorDissolveSignature,
            counterpartyDissolveSignature: propose.counterpartyDissolveSignature,
            signatureVersion: propose.signatureVersion,
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
            counterpartyHonorSignature: model.counterpartyHonorSignature,
            counterpartyHonorTimestamp: model.counterpartyHonorTimestamp,
            counterpartyPartSignature: model.counterpartyPartSignature,
            counterpartyPartTimestamp: model.counterpartyPartTimestamp,
            creatorHonorSignature: model.creatorHonorSignature,
            creatorHonorTimestamp: model.creatorHonorTimestamp,
            creatorPartSignature: model.creatorPartSignature,
            creatorPartTimestamp: model.creatorPartTimestamp,
            dissolvedAt: model.dissolvedAt,
            creatorDissolveSignature: model.creatorDissolveSignature,
            counterpartyDissolveSignature: model.counterpartyDissolveSignature,
            signatureVersion: model.signatureVersion,
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
        model.counterpartyHonorSignature = propose.counterpartyHonorSignature
        model.counterpartyHonorTimestamp = propose.counterpartyHonorTimestamp
        model.counterpartyPartSignature = propose.counterpartyPartSignature
        model.counterpartyPartTimestamp = propose.counterpartyPartTimestamp
        model.creatorHonorSignature = propose.creatorHonorSignature
        model.creatorHonorTimestamp = propose.creatorHonorTimestamp
        model.creatorPartSignature = propose.creatorPartSignature
        model.creatorPartTimestamp = propose.creatorPartTimestamp
        model.dissolvedAt = propose.dissolvedAt
        model.creatorDissolveSignature = propose.creatorDissolveSignature
        model.counterpartyDissolveSignature = propose.counterpartyDissolveSignature
        model.signatureVersion = propose.signatureVersion
        model.updatedAt = Date()

        Logger.propose.debug("ProposeSwiftData update complete: counterpartySignSignature=\(propose.counterpartySignSignature ?? "nil", privacy: .private)")
    }
}
