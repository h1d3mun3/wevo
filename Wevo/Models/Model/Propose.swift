//
//  Propose.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import Foundation

/// Propose model for local storage
/// Holds both the original message and the hashed message
/// Status is derived as a computed property from the presence of local signatures (the server's status field is a reference value only)
struct Propose: Codable, Identifiable {
    let id: UUID
    let spaceID: UUID
    let message: String            // Original message (local only)
    let payloadHash: String        // SHA256 hash (sent as contentHash to API)
    let createdAt: Date
    let updatedAt: Date

    // MARK: - Participants (1:1 PoC)

    /// Public key of the user who created the Propose (Base64 x963)
    let creatorPublicKey: String

    /// Signature attached by the Creator at creation time (Base64 DER)
    let creatorSignature: String

    /// Counterparty's public key (Base64 x963)
    let counterpartyPublicKey: String

    /// Counterparty's signature (nil means not yet signed)
    let counterpartySignSignature: String?

    /// Timestamp used in the Counterparty's sign message (ISO8601, nil means not yet signed)
    let counterpartySignTimestamp: String?

    /// Terminal server status reflected locally (honored/parted/dissolved; nil = not yet finalized)
    let finalStatus: ProposeStatus?

    // MARK: - Local Status (computed property)

    /// Status derived from the presence of local signatures and finalized server status
    /// The status field received from the server is a reference value only; use this instead
    var localStatus: ProposeStatus {
        if let finalStatus = finalStatus {
            return finalStatus
        }
        if counterpartySignSignature != nil {
            return .signed
        }
        return .proposed
    }

    init(
        id: UUID,
        spaceID: UUID,
        message: String,
        creatorPublicKey: String,
        creatorSignature: String,
        counterpartyPublicKey: String,
        counterpartySignSignature: String? = nil,
        counterpartySignTimestamp: String? = nil,
        finalStatus: ProposeStatus? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.spaceID = spaceID
        self.message = message
        // Automatically compute SHA256 hash and store in payloadHash
        self.payloadHash = message.sha256HashedString
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterpartyPublicKey = counterpartyPublicKey
        self.counterpartySignSignature = counterpartySignSignature
        self.counterpartySignTimestamp = counterpartySignTimestamp
        self.finalStatus = finalStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
