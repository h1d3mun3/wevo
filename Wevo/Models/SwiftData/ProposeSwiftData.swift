//
//  ProposeSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class ProposeSwiftData {
    @Attribute(.unique) var id: UUID
    var message: String // 元のメッセージ
    var payloadHash: String // ハッシュ化されたメッセージ
    var spaceID: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // Signatureのデータ
    @Relationship(deleteRule: .cascade) var signatures: [SignatureSwiftData]
    
    init(
        id: UUID,
        message: String,
        payloadHash: String,
        spaceID: UUID,
        signatures: [SignatureSwiftData] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.payloadHash = payloadHash
        self.spaceID = spaceID
        self.signatures = signatures
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
