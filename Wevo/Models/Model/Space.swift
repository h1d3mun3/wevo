//
//  Space.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation

struct Space: Identifiable {
    let id: UUID
    let name: String
    /// All node URLs for this Space (primary + discovered peers).
    let urls: [String]
    let defaultIdentityID: UUID?
    let orderIndex: Int
    let createdAt: Date
    let updatedAt: Date

    /// Primary URL (first in the list). Used for display and single-URL callers.
    var url: String { urls.first ?? "" }

    init(
        id: UUID,
        name: String,
        urls: [String],
        defaultIdentityID: UUID?,
        orderIndex: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.urls = urls
        self.defaultIdentityID = defaultIdentityID
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Backward-compatible initializer for single-URL usage (previews, tests, legacy code).
    init(
        id: UUID,
        name: String,
        url: String,
        defaultIdentityID: UUID?,
        orderIndex: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.init(
            id: id,
            name: name,
            urls: url.isEmpty ? [] : [url],
            defaultIdentityID: defaultIdentityID,
            orderIndex: orderIndex,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
