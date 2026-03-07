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
    var id: UUID = UUID()
    var message: String = "" // 元のメッセージ
    var payloadHash: String = "" // ハッシュ化されたメッセージ
    var spaceID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Signatureのデータ（cascadeで削除時に関連するSignatureも削除）
    @Relationship(deleteRule: .cascade) var signatures: [SignatureSwiftData]?
    
    init(
        id: UUID,
        message: String,
        payloadHash: String,
        spaceID: UUID,
        signatures: [SignatureSwiftData],
        createdAt: Date,
        updatedAt: Date
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
