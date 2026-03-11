//
//  MockSignatureRepository.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Foundation
@testable import Wevo

@MainActor
class MockSignatureRepository: SignatureRepository {
    // MARK: - delete
    var deleteCalled = false
    var deleteError: Error?
    var deletedID: UUID?

    // MARK: - fetchPayloadHash
    var fetchPayloadHashResult: String?
    var fetchPayloadHashError: Error?
    var fetchPayloadHashCalledWithID: UUID?

    // MARK: - Protocol Implementation

    func delete(by id: UUID) throws {
        deleteCalled = true
        deletedID = id

        if let error = deleteError {
            throw error
        }
    }

    func fetchPayloadHash(forSignatureID id: UUID) throws -> String {
        fetchPayloadHashCalledWithID = id

        if let error = fetchPayloadHashError {
            throw error
        }
        guard let result = fetchPayloadHashResult else {
            throw SignatureRepositoryError.proposeNotFoundForSignature(id)
        }
        return result
    }
}
