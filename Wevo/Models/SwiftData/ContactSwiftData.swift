//
//  ContactSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation
import SwiftData

@Model
final class ContactSwiftData {
    var id: UUID = UUID()
    var nickname: String = ""
    var publicKey: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID,
        nickname: String,
        publicKey: String,
        createdAt: Date
    ) {
        self.id = id
        self.nickname = nickname
        self.publicKey = publicKey
        self.createdAt = createdAt
    }
}
