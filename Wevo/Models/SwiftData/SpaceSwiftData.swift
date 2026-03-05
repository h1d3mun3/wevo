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
    var serverURLString: String
    var activeIdentityID: UUID?
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date?

    init(
        id: UUID,
        name: String,
        serverURLString: String,
        activeIdentityID: UUID?,
        orderIndex: Int,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.serverURLString = serverURLString
        self.activeIdentityID = activeIdentityID
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
