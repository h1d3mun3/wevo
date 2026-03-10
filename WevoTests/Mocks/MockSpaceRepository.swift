//
//  MockSpaceRepository.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Foundation
@testable import Wevo

@MainActor
class MockSpaceRepository: SpaceRepository {
    // MARK: - create
    var createCalled = false
    var createError: Error?
    var createdSpace: Space?

    // MARK: - fetchAll
    var fetchAllResult: [Space] = []
    var fetchAllError: Error?

    // MARK: - fetch
    var fetchByIDResult: Space?
    var fetchByIDError: Error?
    var fetchByIDCalledWithID: UUID?

    // MARK: - update
    var updateCalled = false
    var updateError: Error?
    var updatedSpace: Space?

    // MARK: - delete
    var deleteCalled = false
    var deleteError: Error?
    var deletedID: UUID?

    // MARK: - deleteAll
    var deleteAllCalled = false
    var deleteAllError: Error?
    var deleteAllForSpaceID: UUID?

    // MARK: - Protocol Implementation

    func create(_ space: Space) throws {
        createCalled = true
        createdSpace = space

        if let error = createError {
            throw error
        }
    }

    func fetchAll() throws -> [Space] {
        if let error = fetchAllError {
            throw error
        }
        return fetchAllResult
    }

    func fetch(by id: UUID) throws -> Space {
        fetchByIDCalledWithID = id

        if let error = fetchByIDError {
            throw error
        }
        guard let result = fetchByIDResult else {
            throw NSError(domain: "MockSpaceRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Space not found"])
        }
        return result
    }

    func update(_ space: Space) throws {
        updateCalled = true
        updatedSpace = space

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

    func deleteAll() throws {
        deleteAllCalled = true

        if let error = deleteAllError {
            throw error
        }
    }
}
