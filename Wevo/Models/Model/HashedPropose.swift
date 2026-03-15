//
//  HashedPropose.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// Struct representing counterparty information (corresponds to the counterparties field in API responses)
struct ProposeCounterparty: Codable {
    /// Counterparty's public key in Base64 x963 format
    let publicKey: String
    /// Counterparty's sign signature (nil = unsigned)
    let signSignature: String?
    /// Counterparty's honor signature (nil = not yet executed)
    let honorSignature: String?
    /// Counterparty's part signature (nil = not yet executed)
    let partSignature: String?
}

/// Propose model for API communication
/// Contains only the hashed message (does not include the original message)
/// Corresponds to the server's ProposeResponse
struct HashedPropose: Codable, Identifiable {
    let id: UUID
    /// SHA256 hash (received as contentHash from API, treated internally as payloadHash)
    let contentHash: String
    /// Creator's public key (Base64 x963)
    let creatorPublicKey: String
    /// Signature attached by the Creator at creation time (Base64 DER)
    let creatorSignature: String
    /// List of counterparties (only 1 in PoC)
    let counterparties: [ProposeCounterparty]
    /// Creator's honor signature (nil = not yet executed)
    let honorCreatorSignature: String?
    /// Creator's part signature (nil = not yet executed)
    let partCreatorSignature: String?
    /// Status managed by the server (reference value only)
    let status: ProposeStatus
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        contentHash: String,
        creatorPublicKey: String,
        creatorSignature: String,
        counterparties: [ProposeCounterparty],
        honorCreatorSignature: String? = nil,
        partCreatorSignature: String? = nil,
        status: ProposeStatus = .proposed,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.contentHash = contentHash
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterparties = counterparties
        self.honorCreatorSignature = honorCreatorSignature
        self.partCreatorSignature = partCreatorSignature
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
