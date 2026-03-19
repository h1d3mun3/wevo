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

    /// Public key of the user who created the Propose (JWK format)
    let creatorPublicKey: String

    /// Signature attached by the Creator at creation time (Base64 DER)
    let creatorSignature: String

    /// Counterparty's public key (JWK format)
    let counterpartyPublicKey: String

    /// Counterparty's signature (nil means not yet signed)
    let counterpartySignSignature: String?

    /// Timestamp used in the Counterparty's sign message (ISO8601, nil means not yet signed)
    let counterpartySignTimestamp: String?

    /// Counterparty's honor signature (nil = not yet executed)
    let counterpartyHonorSignature: String?

    /// Timestamp used in the Counterparty's honor message (ISO8601, nil = not yet executed)
    let counterpartyHonorTimestamp: String?

    /// Counterparty's part signature (nil = not yet executed)
    let counterpartyPartSignature: String?

    /// Timestamp used in the Counterparty's part message (ISO8601, nil = not yet executed)
    let counterpartyPartTimestamp: String?

    /// Creator's honor signature (nil = not yet executed)
    let creatorHonorSignature: String?

    /// Timestamp used in the Creator's honor message (ISO8601, nil = not yet executed)
    let creatorHonorTimestamp: String?

    /// Creator's part signature (nil = not yet executed)
    let creatorPartSignature: String?

    /// Timestamp used in the Creator's part message (ISO8601, nil = not yet executed)
    let creatorPartTimestamp: String?

    /// Timestamp when the propose was dissolved (ISO8601, nil = not dissolved)
    let dissolvedAt: String?

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
        counterpartyHonorSignature: String? = nil,
        counterpartyHonorTimestamp: String? = nil,
        counterpartyPartSignature: String? = nil,
        counterpartyPartTimestamp: String? = nil,
        creatorHonorSignature: String? = nil,
        creatorHonorTimestamp: String? = nil,
        creatorPartSignature: String? = nil,
        creatorPartTimestamp: String? = nil,
        dissolvedAt: String? = nil,
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
