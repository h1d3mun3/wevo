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

    init(
        id: UUID,
        publicKey: String,
        signatureData: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.publicKey = publicKey
        self.signatureData = signatureData
        self.createdAt = createdAt
    }
}
