//
//  SignatureRepository.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import SwiftData

enum SignatureRepositoryError: Error {
    case signatureNotFound(UUID)
    case proposeNotFoundForSignature(UUID)
    case deleteError(Error)
    case fetchError(Error)
}

@MainActor
protocol SignatureRepository {
    func fetchAll() throws -> [Signature]
    func delete(by id: UUID) throws
    func fetchPayloadHash(forSignatureID id: UUID) throws -> String
}

/// Repository providing Signature operations using SwiftData
final class SignatureRepositoryImpl: SignatureRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    /// Retrieve all Signatures (sorted by creation date descending)
    func fetchAll() throws -> [Signature] {
        let descriptor = FetchDescriptor<SignatureSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            // Convert SignatureSwiftData to Signature entity
            return models.map { model in
                Signature(
                    id: model.id,
                    publicKey: model.publicKey,
                    signature: model.signatureData,
                    createdAt: model.createdAt
                )
            }
        } catch {
            throw SignatureRepositoryError.fetchError(error)
        }
    }

    // MARK: - Delete

    func delete(by id: UUID) throws {
        let predicate = #Predicate<SignatureSwiftData> { model in
            model.id == id
        }

        var descriptor = FetchDescriptor<SignatureSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw SignatureRepositoryError.signatureNotFound(id)
            }

            modelContext.delete(model)
            try modelContext.save()
        } catch let error as SignatureRepositoryError {
            throw error
        } catch {
            throw SignatureRepositoryError.deleteError(error)
        }
    }

    // MARK: - Fetch

    /// Retrieve the payloadHash of the Propose associated with a signature ID
    /// Since there is no relation between SignatureSwiftData and ProposeSwiftData in the new API,
    /// this always throws SignatureRepositoryError.proposeNotFoundForSignature
    /// (this functionality is not used in the new API)
    func fetchPayloadHash(forSignatureID id: UUID) throws -> String {
        throw SignatureRepositoryError.proposeNotFoundForSignature(id)
    }
}
