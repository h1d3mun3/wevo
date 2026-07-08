//
//  ImportProposeUseCase.swift
//  Wevo
//

import Foundation
import os

enum ImportProposeUseCaseError: Error {
    case failedToSave
    case invalidSignature
    /// The incoming file shares an existing Propose's ID but disagrees on its immutable
    /// identity (creator key, counterparty key, or content hash) — i.e. it is not the same
    /// agreement. Merging it would graft the file's signatures onto the local participants.
    case conflictingProposeIdentity
}

protocol ImportProposeUseCase {
    func readFromFile(url: URL) throws -> ProposeExportData
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
            // The participants of a Propose are fixed at creation. `verifyAllSignatures` above
            // only proves the incoming signatures are valid *for the keys in the file*; it does
            // NOT prove they belong to the same agreement. Without this guard, an attacker who
            // knows the Propose ID could craft a file with their OWN keys plus valid
            // "honored/signed/…" signatures, and the merge below — which keeps the local
            // participant keys but adopts the incoming signature fields — would display a forged
            // state transition attributed to the real counterparty. Requiring the participant
            // keys to match means every adopted signature must validate against the REAL
            // participants' keys (the content hash is already bound by the verified creator
            // signature), so only genuine signatures can ever be merged.
            guard propose.creatorPublicKey == existing.creatorPublicKey,
                  propose.counterpartyPublicKey == existing.counterpartyPublicKey else {
                throw ImportProposeUseCaseError.conflictingProposeIdentity
            }

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
                creatorDissolveSignature: propose.creatorDissolveSignature ?? existing.creatorDissolveSignature,
                creatorDissolveTimestamp: propose.creatorDissolveTimestamp ?? existing.creatorDissolveTimestamp,
                counterpartyDissolveSignature: propose.counterpartyDissolveSignature ?? existing.counterpartyDissolveSignature,
                counterpartyDissolveTimestamp: propose.counterpartyDissolveTimestamp ?? existing.counterpartyDissolveTimestamp,
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
            guard let timestamp = propose.creatorDissolveTimestamp else {
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
            guard let timestamp = propose.counterpartyDissolveTimestamp else {
                throw ImportProposeUseCaseError.invalidSignature
            }
            let message = "dissolved." + propose.id.uuidString + propose.payloadHash + propose.counterpartyPublicKey + timestamp
            guard verify(sig, for: message, publicKey: propose.counterpartyPublicKey) else {
                Logger.propose.warning("Import rejected: invalid counterparty dissolve signature \(propose.id, privacy: .private)")
                throw ImportProposeUseCaseError.invalidSignature
            }
        }
    }

    func readFromFile(url: URL) throws -> ProposeExportData {
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ProposeAPIClient.iso8601Formatter.date(from: string)
                ?? ProposeAPIClient.iso8601FormatterBasic.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
        }
        return try decoder.decode(ProposeExportData.self, from: jsonData)
    }

    /// Returns true only if the signature is cryptographically valid. Any error (malformed data etc.) is treated as invalid.
    private func verify(_ signature: String, for message: String, publicKey: String) -> Bool {
        (try? keychainRepository.verifySignature(signature, for: message, withPublicKeyString: publicKey)) == true
    }
}
