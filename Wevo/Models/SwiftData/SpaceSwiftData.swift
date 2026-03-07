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
    @Attribute(.unique) var id: UUID
    var name: String
    var urlString: String
    var defaultIdentityID: UUID?
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        name: String,
        urlString: String,
        defaultIdentityID: UUID?,
        orderIndex: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.defaultIdentityID = defaultIdentityID
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
