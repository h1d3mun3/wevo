//
//  SpaceModel.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation
import SwiftData

@Model
final class SpaceSwiftData {
    var id: UUID = UUID()
    var name: String = ""
    /// All node URLs (primary + peers).
    var nodeURLs: [String] = []
    var defaultIdentityID: UUID?
    var orderIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID,
        name: String,
        nodeURLs: [String],
        defaultIdentityID: UUID?,
        orderIndex: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.nodeURLs = nodeURLs
        self.defaultIdentityID = defaultIdentityID
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
