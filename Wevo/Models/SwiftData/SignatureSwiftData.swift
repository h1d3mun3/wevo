//
//  SignatureSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

/// Signature model persisted using SwiftData
/// Relation to ProposeSwiftData has been removed (the new API stores signature data directly within the Propose)
@Model
final class SignatureSwiftData {
    var id: UUID = UUID()
    var publicKey: String = ""
    var signatureData: String = ""
    var createdAt: Date = Date()

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
