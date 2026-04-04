//
//  ImportProposeUseCase.swift
//  Wevo
//

import Foundation
import os

enum ImportProposeUseCaseError: Error {
    case failedToSave
    case invalidSignature
}

protocol ImportProposeUseCase {
    func execute(propose: Propose, spaceID: UUID) throws
}

struct ImportProposeUseCaseImpl {
    let proposeRepository: ProposeRepository
    let keychainRepository: KeychainRepository

    init(proposeRepository: ProposeRepository, keychainRepository: KeychainRepository) {
        self.proposeRepository = proposeRepository
        self.keychainRepository = keychainRepository
    }
}

extension ImportProposeUseCaseImpl: ImportProposeUseCase {
    /// Imports a Propose received via AirDrop or file sharing.
    ///
    /// - If no local Propose with the same ID exists, creates a new one in the given space.
    /// - If a local Propose already exists (e.g. the creator receiving back a signed copy),
    ///   merges the incoming signatures into the existing record.
    ///   Local `spaceID` and `message` are always preserved; incoming non-nil fields win for
    ///   all signature fields so that signatures are never lost in either direction.
    func execute(propose: Propose, spaceID: UUID) throws {
        // Verify all signatures in the incoming Propose before touching local storage
        try verifyAllSignatures(in: propose)

        if let existing = try? proposeRepository.fetch(by: propose.id) {
            let merged = Propose(
                id: existing.id,
                spaceID: existing.spaceID,
                message: existing.message,
                creatorPublicKey: existing.creatorPublicKey,
                creatorSignature: existing.creatorSignature,
                counterpartyPublicKey: existing.counterpartyPublicKey,
                counterpartySignSignature: propose.counterpartySignSignature ?? existing.counterpartySignSignature,
                counterpartySignTimestamp: propose.counterpartySignTimestamp ?? existing.counterpartySignTimestamp,
                counterpartyHonorSignature: propose.counterpartyHonorSignature ?? existing.counterpartyHonorSignature,
                counterpartyHonorTimestamp: propose.counterpartyHonorTimestamp ?? existing.counterpartyHonorTimestamp,
                counterpartyPartSignature: propose.counterpartyPartSignature ?? existing.counterpartyPartSignature,
                counterpartyPartTimestamp: propose.counterpartyPartTimestamp ?? existing.counterpartyPartTimestamp,
                creatorHonorSignature: propose.creatorHonorSignature ?? existing.creatorHonorSignature,
                creatorHonorTimestamp: propose.creatorHonorTimestamp ?? existing.creatorHonorTimestamp,
                creatorPartSignature: propose.creatorPartSignature ?? existing.creatorPartSignature,
                creatorPartTimestamp: propose.creatorPartTimestamp ?? existing.creatorPartTimestamp,
                dissolvedAt: propose.dissolvedAt ?? existing.dissolvedAt,
                creatorDissolveSignature: propose.creatorDissolveSignature ?? existing.creatorDissolveSignature,
                counterpartyDissolveSignature: propose.counterpartyDissolveSignature ?? existing.counterpartyDissolveSignature,
                signatureVersion: existing.signatureVersion,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
            do {
                try proposeRepository.update(merged)
            } catch {
                throw ImportProposeUseCaseError.failedToSave
            }
        } else {
            do {
                try proposeRepository.create(propose, spaceID: spaceID)
            } catch {
                throw ImportProposeUseCaseError.failedToSave
            }
        }
    }

    // MARK: - Signature Verification

    private func verifyAllSignatures(in propose: Propose) throws {
        // Creator signature (always present — establishes authenticity of the Propose itself)
        // v1: "proposed." + proposeId + contentHash + creatorPublicKey + sortedCounterpartyKeys + createdAt
        let createdAtISO = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)
        let creatorMessage = "proposed."
            + propose.id.uuidString
            + propose.payloadHash
            + propose.creatorPublicKey
            + [propose.counterpartyPublicKey].sorted().joined()
            + createdAtISO
        guard verify(propose.creatorSignature, for: creatorMessage, publicKey: propose.creatorPublicKey) else {
            Logger.propose.warning("Import rejected: invalid creator signature \(propose.id, privacy: .private)")
            throw ImportProposeUseCaseError.invalidSignature
        }

        // Counterparty sign signature
        // v1: "signed." + proposeId + contentHash + signerPublicKey + timestamp (unchanged)
        if let sig = propose.counterpartySignSignature {
            guard let timestamp = propose.counterpartySignTimestamp else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "signed." + propose.id.uuidString + propose.payloadHash + propose.counterpartyPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.counterpartyPublicKey) else {
                Logger.propose.warning("Import rejected: invalid counterparty sign signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }

        // Counterparty honor signature
        // v1: "honored." + proposeId + contentHash + signerPublicKey + timestamp
        if let sig = propose.counterpartyHonorSignature {
            guard let timestamp = propose.counterpartyHonorTimestamp else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "honored." + propose.id.uuidString + propose.payloadHash + propose.counterpartyPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.counterpartyPublicKey) else {
                Logger.propose.warning("Import rejected: invalid counterparty honor signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }

        // Counterparty part signature
        // v1: "parted." + proposeId + contentHash + signerPublicKey + timestamp
        if let sig = propose.counterpartyPartSignature {
            guard let timestamp = propose.counterpartyPartTimestamp else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "parted." + propose.id.uuidString + propose.payloadHash + propose.counterpartyPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.counterpartyPublicKey) else {
                Logger.propose.warning("Import rejected: invalid counterparty part signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }

        // Creator honor signature
        // v1: "honored." + proposeId + contentHash + signerPublicKey + timestamp
        if let sig = propose.creatorHonorSignature {
            guard let timestamp = propose.creatorHonorTimestamp else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "honored." + propose.id.uuidString + propose.payloadHash + propose.creatorPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.creatorPublicKey) else {
                Logger.propose.warning("Import rejected: invalid creator honor signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }

        // Creator part signature
        // v1: "parted." + proposeId + contentHash + signerPublicKey + timestamp
        if let sig = propose.creatorPartSignature {
            guard let timestamp = propose.creatorPartTimestamp else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "parted." + propose.id.uuidString + propose.payloadHash + propose.creatorPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.creatorPublicKey) else {
                Logger.propose.warning("Import rejected: invalid creator part signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }

        // Creator dissolve signature
        // v1: "dissolved." + proposeId + contentHash + signerPublicKey + timestamp
        if let sig = propose.creatorDissolveSignature {
            guard let timestamp = propose.dissolvedAt else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "dissolved." + propose.id.uuidString + propose.payloadHash + propose.creatorPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.creatorPublicKey) else {
                Logger.propose.warning("Import rejected: invalid creator dissolve signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }

        // Counterparty dissolve signature
        // v1: "dissolved." + proposeId + contentHash + signerPublicKey + timestamp
        if let sig = propose.counterpartyDissolveSignature {
            guard let timestamp = propose.dissolvedAt else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "dissolved." + propose.id.uuidString + propose.payloadHash + propose.counterpartyPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.counterpartyPublicKey) else {
                Logger.propose.warning("Import rejected: invalid counterparty dissolve signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }
    }

    /// Returns true only if the signature is cryptographically valid. Any error (malformed data etc.) is treated as invalid.
    private func verify(_ signature: String, for message: String, publicKey: String) -> Bool {
        (try? keychainRepository.verifySignature(signature, for: message, withPublicKeyString: publicKey)) == true
    }
}
