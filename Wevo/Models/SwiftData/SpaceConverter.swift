//
//  SpaceConverter.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation

/// Handles bidirectional conversion between the Space struct and SpaceModel
struct SpaceConverter {

    /// Converts a Space struct to SpaceModel
    static func toModel(from space: Space) -> SpaceSwiftData {
        let model = SpaceSwiftData(
            id: space.id,
            name: space.name,
            urlString: space.url,
            defaultIdentityID: space.defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: space.updatedAt
        )
        model.nodeURLs = space.urls
        return model
    }

    /// Converts SpaceModel to a Space struct
    static func toEntity(from model: SpaceSwiftData) -> Space {
        // Prefer nodeURLs when available; fall back to urlString for legacy records
        let urls: [String]
        if model.nodeURLs.isEmpty {
            urls = model.urlString.isEmpty ? [] : [model.urlString]
        } else {
            urls = model.nodeURLs
        }
        return Space(
            id: model.id,
            name: model.name,
            urls: urls,
            defaultIdentityID: model.defaultIdentityID,
            orderIndex: model.orderIndex,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    /// Converts multiple SpaceModel objects
    static func toEntities(from models: [SpaceSwiftData]) -> [Space] {
        return models.map { model in
            toEntity(from: model)
        }
    }

    /// Updates a SpaceModel with an existing Space struct
    static func updateModel(_ model: SpaceSwiftData, with space: Space) {
        model.name = space.name
        model.urlString = space.url
        model.nodeURLs = space.urls
        model.defaultIdentityID = space.defaultIdentityID
        model.orderIndex = space.orderIndex
        model.updatedAt = Date()
    }
}
