//
//  MockContactRepository.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Foundation
@testable import Wevo

@MainActor
class MockContactRepository: ContactRepository {
    // MARK: - create
    var createCalled = false
    var createError: Error?
    var createdContact: Contact?

    // MARK: - fetchAll
    var fetchAllResult: [Contact] = []
    var fetchAllError: Error?

    // MARK: - fetch
    var fetchByIDResult: Contact?
    var fetchByIDError: Error?
    var fetchByIDCalledWithID: UUID?

    // MARK: - update
    var updateCalled = false
    var updateError: Error?
    var updatedContact: Contact?

    // MARK: - delete
    var deleteCalled = false
    var deleteError: Error?
    var deletedID: UUID?

    // MARK: - Protocol Implementation

    func create(_ contact: Contact) throws {
        createCalled = true
        createdContact = contact

        if let error = createError {
            throw error
        }
    }

    func fetchAll() throws -> [Contact] {
        if let error = fetchAllError {
            throw error
        }
        return fetchAllResult
    }

    func fetch(by id: UUID) throws -> Contact {
        fetchByIDCalledWithID = id

        if let error = fetchByIDError {
            throw error
        }
        guard let result = fetchByIDResult else {
            throw NSError(domain: "MockContactRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Contact not found"])
        }
        return result
    }

    func update(_ contact: Contact) throws {
        updateCalled = true
        updatedContact = contact

        if let error = updateError {
            throw error
        }
    }

    func delete(by id: UUID) throws {
        deleteCalled = true
        deletedID = id

        if let error = deleteError {
            throw error
        }
    }
}
