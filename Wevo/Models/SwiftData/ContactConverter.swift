//
//  ContactConverter.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

/// Handles bidirectional conversion between the Contact struct and ContactSwiftData
struct ContactConverter {

    /// Converts a Contact struct to ContactSwiftData
    static func toModel(from contact: Contact) -> ContactSwiftData {
        return ContactSwiftData(
            id: contact.id,
            nickname: contact.nickname,
            publicKey: contact.publicKey,
            createdAt: contact.createdAt
        )
    }

    /// Converts ContactSwiftData to a Contact struct
    static func toEntity(from model: ContactSwiftData) -> Contact {
        return Contact(
            id: model.id,
            nickname: model.nickname,
            publicKey: model.publicKey,
            createdAt: model.createdAt
        )
    }

    /// Converts multiple ContactSwiftData objects
    static func toEntities(from models: [ContactSwiftData]) -> [Contact] {
        return models.map { toEntity(from: $0) }
    }

    /// Updates a ContactSwiftData with an existing Contact struct
    static func updateModel(_ model: ContactSwiftData, with contact: Contact) {
        model.nickname = contact.nickname
        model.publicKey = contact.publicKey
    }
}
