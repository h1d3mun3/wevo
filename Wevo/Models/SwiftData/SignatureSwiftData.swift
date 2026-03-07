//
//  SignatureSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class SignatureSwiftData {
    @Attribute(.unique) var id: UUID
    var publicKey: String
    var signatureData: String
    var createdAt: Date
    
    // ProposeSwiftDataとの関係（逆方向）
    @Relationship(inverse: \ProposeSwiftData.signatures) var propose: ProposeSwiftData?

    init(
        id: UUID,
        publicKey: String,
        signatureData: String,
        createdAt: Date
    ) {
        self.id = id
        self.publicKey = publicKey
        self.signatureData = signatureData
        self.createdAt = createdAt
    }
}
