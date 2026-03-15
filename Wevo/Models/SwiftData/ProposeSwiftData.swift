//
//  ProposeSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

/// Propose model persisted using SwiftData
/// Must have optional or default values for CloudKit compatibility
@Model
final class ProposeSwiftData {
    var id: UUID = UUID()
    var message: String = ""       // Original message
    var payloadHash: String = ""   // SHA256 hash (sent as contentHash to API)
    var spaceID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Participant Fields (1:1 PoC)

    /// Creator's public key (Base64 x963)
    var creatorPublicKey: String = ""

    /// Signature attached by the Creator at creation time (Base64 DER)
    var creatorSignature: String = ""

    /// Counterparty's public key (Base64 x963)
    var counterpartyPublicKey: String = ""

    /// Counterparty's signature (nil = unsigned)
    var counterpartySignSignature: String? = nil

    init(
        id: UUID,
        message: String,
        payloadHash: String,
        spaceID: UUID,
        creatorPublicKey: String,
        creatorSignature: String,
        counterpartyPublicKey: String,
        counterpartySignSignature: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.message = message
        self.payloadHash = payloadHash
        self.spaceID = spaceID
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterpartyPublicKey = counterpartyPublicKey
        self.counterpartySignSignature = counterpartySignSignature
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
