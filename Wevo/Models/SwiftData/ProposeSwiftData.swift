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

    /// Creator's public key (JWK format)
    var creatorPublicKey: String = ""

    /// Signature attached by the Creator at creation time (Base64 DER)
    var creatorSignature: String = ""

    /// Counterparty's public key (JWK format)
    var counterpartyPublicKey: String = ""

    /// Counterparty's signature (nil = unsigned)
    var counterpartySignSignature: String? = nil

    /// Timestamp used in the Counterparty's sign message (ISO8601, nil = unsigned)
    var counterpartySignTimestamp: String? = nil

    /// Counterparty's honor signature (nil = not yet executed)
    var counterpartyHonorSignature: String? = nil

    /// Timestamp used in the Counterparty's honor message (ISO8601, nil = not yet executed)
    var counterpartyHonorTimestamp: String? = nil

    /// Counterparty's part signature (nil = not yet executed)
    var counterpartyPartSignature: String? = nil

    /// Timestamp used in the Counterparty's part message (ISO8601, nil = not yet executed)
    var counterpartyPartTimestamp: String? = nil

    /// Creator's honor signature (nil = not yet executed)
    var creatorHonorSignature: String? = nil

    /// Timestamp used in the Creator's honor message (ISO8601, nil = not yet executed)
    var creatorHonorTimestamp: String? = nil

    /// Creator's part signature (nil = not yet executed)
    var creatorPartSignature: String? = nil

    /// Timestamp used in the Creator's part message (ISO8601, nil = not yet executed)
    var creatorPartTimestamp: String? = nil

    /// Timestamp when the propose was dissolved (ISO8601, nil = not dissolved)
    var dissolvedAt: String? = nil

    /// Terminal server status reflected locally (honored/parted/dissolved raw value; nil = not yet finalized)
    var finalStatus: String? = nil

    /// Signature scheme version applied to all signatures on this Propose
    var signatureVersion: Int = 1

    init(
        id: UUID,
        message: String,
        payloadHash: String,
        spaceID: UUID,
        creatorPublicKey: String,
        creatorSignature: String,
        counterpartyPublicKey: String,
        counterpartySignSignature: String? = nil,
        counterpartySignTimestamp: String? = nil,
        counterpartyHonorSignature: String? = nil,
        counterpartyHonorTimestamp: String? = nil,
        counterpartyPartSignature: String? = nil,
        counterpartyPartTimestamp: String? = nil,
        creatorHonorSignature: String? = nil,
        creatorHonorTimestamp: String? = nil,
        creatorPartSignature: String? = nil,
        creatorPartTimestamp: String? = nil,
        dissolvedAt: String? = nil,
        finalStatus: String? = nil,
        signatureVersion: Int = 1,
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
        self.counterpartySignTimestamp = counterpartySignTimestamp
        self.counterpartyHonorSignature = counterpartyHonorSignature
        self.counterpartyHonorTimestamp = counterpartyHonorTimestamp
        self.counterpartyPartSignature = counterpartyPartSignature
        self.counterpartyPartTimestamp = counterpartyPartTimestamp
        self.creatorHonorSignature = creatorHonorSignature
        self.creatorHonorTimestamp = creatorHonorTimestamp
        self.creatorPartSignature = creatorPartSignature
        self.creatorPartTimestamp = creatorPartTimestamp
        self.dissolvedAt = dissolvedAt
        self.finalStatus = finalStatus
        self.signatureVersion = signatureVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
