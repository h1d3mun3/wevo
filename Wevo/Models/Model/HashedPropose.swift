//
//  HashedPropose.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// Struct representing counterparty information (corresponds to the counterparties field in API responses)
struct ProposeCounterparty: Codable {
    /// Counterparty's public key (JWK format)
    let publicKey: String
    /// Counterparty's sign signature (nil = unsigned)
    let signSignature: String?
    /// Timestamp used in the sign message (ISO8601, nil = unsigned)
    let signTimestamp: String?
    /// Counterparty's honor signature (nil = not yet executed)
    let honorSignature: String?
    /// Timestamp used in the honor message (ISO8601, nil = not yet executed)
    let honorTimestamp: String?
    /// Counterparty's part signature (nil = not yet executed)
    let partSignature: String?
    /// Timestamp used in the part message (ISO8601, nil = not yet executed)
    let partTimestamp: String?
    /// Counterparty's dissolve signature (nil = not dissolved by counterparty)
    let dissolveSignature: String?
    /// Timestamp used in the counterparty's dissolve message (ISO8601, nil = not dissolved by counterparty)
    let dissolveTimestamp: String?

    init(
        publicKey: String,
        signSignature: String? = nil,
        signTimestamp: String? = nil,
        honorSignature: String? = nil,
        honorTimestamp: String? = nil,
        partSignature: String? = nil,
        partTimestamp: String? = nil,
        dissolveSignature: String? = nil,
        dissolveTimestamp: String? = nil
    ) {
        self.publicKey = publicKey
        self.signSignature = signSignature
        self.signTimestamp = signTimestamp
        self.honorSignature = honorSignature
        self.honorTimestamp = honorTimestamp
        self.partSignature = partSignature
        self.partTimestamp = partTimestamp
        self.dissolveSignature = dissolveSignature
        self.dissolveTimestamp = dissolveTimestamp
    }
}

/// Propose model for API communication
/// Contains only the hashed message (does not include the original message)
/// Corresponds to the server's ProposeResponse
struct HashedPropose: Codable, Identifiable {
    let id: UUID
    /// SHA256 hash (received as contentHash from API, treated internally as payloadHash)
    let contentHash: String
    /// Creator's public key (JWK format)
    let creatorPublicKey: String
    /// Signature attached by the Creator at creation time (Base64 DER)
    let creatorSignature: String
    /// List of counterparties (only 1 in PoC)
    let counterparties: [ProposeCounterparty]
    /// Creator's honor signature (nil = not yet executed)
    let honorCreatorSignature: String?
    /// Timestamp used in the creator's honor message (ISO8601, nil = not yet executed)
    let honorCreatorTimestamp: String?
    /// Creator's part signature (nil = not yet executed)
    let partCreatorSignature: String?
    /// Timestamp used in the creator's part message (ISO8601, nil = not yet executed)
    let partCreatorTimestamp: String?
    /// Timestamp when the propose was dissolved (ISO8601, nil = not dissolved)
    let dissolvedAt: String?
    /// Creator's dissolve signature (nil = not dissolved by creator)
    let creatorDissolveSignature: String?
    /// Timestamp used in the Creator's dissolve message (ISO8601, nil = not dissolved by creator)
    let creatorDissolveTimestamp: String?
    /// Status managed by the server (reference value only)
    let status: ProposeStatus
    /// Signature scheme version (v1 = signerPublicKey embedded in every signed message)
    let signatureVersion: Int
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        contentHash: String,
        creatorPublicKey: String,
        creatorSignature: String,
        counterparties: [ProposeCounterparty],
        honorCreatorSignature: String? = nil,
        honorCreatorTimestamp: String? = nil,
        partCreatorSignature: String? = nil,
        partCreatorTimestamp: String? = nil,
        dissolvedAt: String? = nil,
        creatorDissolveSignature: String? = nil,
        creatorDissolveTimestamp: String? = nil,
        status: ProposeStatus = .proposed,
        signatureVersion: Int = 1,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.contentHash = contentHash
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterparties = counterparties
        self.honorCreatorSignature = honorCreatorSignature
        self.honorCreatorTimestamp = honorCreatorTimestamp
        self.partCreatorSignature = partCreatorSignature
        self.partCreatorTimestamp = partCreatorTimestamp
        self.dissolvedAt = dissolvedAt
        self.creatorDissolveSignature = creatorDissolveSignature
        self.creatorDissolveTimestamp = creatorDissolveTimestamp
        self.status = status
        self.signatureVersion = signatureVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
