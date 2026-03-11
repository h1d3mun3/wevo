//
//  MockProposeRepository.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Foundation
@testable import Wevo

@MainActor
class MockProposeRepository: ProposeRepository {
    // MARK: - create
    var createCalled = false
    var createError: Error?
    var createdPropose: Propose?
    var createdSpaceID: UUID?

    // MARK: - fetchAll
    var fetchAllResult: [Propose] = []
    var fetchAllError: Error?
    var fetchAllForSpaceID: UUID?

    // MARK: - fetchAllOrphaned
    var fetchAllOrphanedResult: [Propose] = []
    var fetchAllOrphanedError: Error?
    var fetchAllOrphanedValidSpaceIDs: Set<UUID>?

    // MARK: - fetch
    var fetchByIDResult: Propose?
    var fetchByIDError: Error?
    var fetchByIDCalledWithID: UUID?

    // MARK: - update
    var updateCalled = false
    var updateError: Error?
    var updatedPropose: Propose?

    // MARK: - delete
    var deleteCalled = false
    var deleteError: Error?
    var deletedID: UUID?

    // MARK: - deleteAll
    var deleteAllCalled = false
    var deleteAllError: Error?
    var deleteAllForSpaceID: UUID?

    // MARK: - fetchAll (no filter)
    var fetchAllNoFilterResult: [Propose] = []
    var fetchAllNoFilterError: Error?
    var fetchAllNoFilterCalled = false

    // MARK: - Protocol Implementation

    func fetchAll() throws -> [Propose] {
        fetchAllNoFilterCalled = true

        if let error = fetchAllNoFilterError {
            throw error
        }
        return fetchAllNoFilterResult
    }

    func create(_ propose: Propose, spaceID: UUID) throws {
        createCalled = true
        createdPropose = propose
        createdSpaceID = spaceID

        if let error = createError {
            throw error
        }
    }

    func fetchAll(for spaceID: UUID) throws -> [Propose] {
        fetchAllForSpaceID = spaceID

        if let error = fetchAllError {
            throw error
        }
        return fetchAllResult
    }

    func fetchAllOrphaned(validSpaceIDs: Set<UUID>) throws -> [Propose] {
        fetchAllOrphanedValidSpaceIDs = validSpaceIDs

        if let error = fetchAllOrphanedError {
            throw error
        }
        return fetchAllOrphanedResult
    }

    func fetch(by id: UUID) throws -> Propose {
        fetchByIDCalledWithID = id

        if let error = fetchByIDError {
            throw error
        }
        guard let result = fetchByIDResult else {
            throw NSError(domain: "MockProposeRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Propose not found"])
        }
        return result
    }

    func update(_ propose: Propose) throws {
        updateCalled = true
        updatedPropose = propose

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

    func deleteAll(for spaceID: UUID) throws {
        deleteAllCalled = true
        deleteAllForSpaceID = spaceID

        if let error = deleteAllError {
            throw error
        }
    }
}
