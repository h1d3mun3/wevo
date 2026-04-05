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
    var urlString: String = ""
    /// All node URLs (primary + peers). Empty for legacy records — converter falls back to urlString.
    var nodeURLs: [String] = []
    var defaultIdentityID: UUID?
    var orderIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
