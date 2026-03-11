//
//  ProposeRepositoryTests.swift
//  WevoTests
//

import Testing
import Foundation
import SwiftData
@testable import Wevo

@Suite(.serialized)
@MainActor
struct ProposeRepositoryTests {

    private func makeRepository() throws -> (ProposeRepositoryImpl, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SpaceSwiftData.self, ProposeSwiftData.self, SignatureSwiftData.self,
            configurations: config
        )
        return (ProposeRepositoryImpl(modelContext: container.mainContext), container)
    }

    private func makePropose(
        id: UUID = UUID(),
        spaceID: UUID = UUID(),
        message: String = "test message",
        signatures: [Signature] = []
    ) -> Propose {
        Propose(
            id: id,
            spaceID: spaceID,
            message: message,
            signatures: signatures,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeSignature(publicKey: String = "pk", signature: String = "sig") -> Signature {
        Signature(id: UUID(), publicKey: publicKey, signature: signature, createdAt: .now)
    }

    // MARK: - Create & Fetch

    @Test func testCreateAndFetchPropose() throws {
        let (repo, _container) = try makeRepository()
        let spaceID = UUID()
        let propose = makePropose(spaceID: spaceID)

        try repo.create(propose, spaceID: spaceID)
        let fetched = try repo.fetch(by: propose.id)

        #expect(fetched.id == propose.id)
        #expect(fetched.message == propose.message)
    }

    @Test func testCreateProposeWithSignatures() throws {
        let (repo, _container) = try makeRepository()
        let spaceID = UUID()
        let sig = makeSignature(publicKey: "key1")
        let propose = makePropose(spaceID: spaceID, signatures: [sig])

        try repo.create(propose, spaceID: spaceID)
        let fetched = try repo.fetch(by: propose.id)

        #expect(fetched.signatures.count == 1)
        #expect(fetched.signatures[0].publicKey == "key1")
    }

    // MARK: - FetchAll

    @Test func testFetchAllReturnsAllProposes() throws {
        let (repo, _container) = try makeRepository()
        let spaceID = UUID()

        try repo.create(makePropose(spaceID: spaceID, message: "msg1"), spaceID: spaceID)
        try repo.create(makePropose(spaceID: spaceID, message: "msg2"), spaceID: spaceID)

        let all = try repo.fetchAll()
        #expect(all.count == 2)
    }

    @Test func testFetchAllForSpaceIDFiltersCorrectly() throws {
        let (repo, _container) = try makeRepository()
        let spaceA = UUID()
        let spaceB = UUID()

        try repo.create(makePropose(spaceID: spaceA, message: "A"), spaceID: spaceA)
        try repo.create(makePropose(spaceID: spaceB, message: "B"), spaceID: spaceB)

        let result = try repo.fetchAll(for: spaceA)
        #expect(result.count == 1)
        #expect(result[0].message == "A")
    }

    // MARK: - FetchAllOrphaned

    @Test func testFetchAllOrphanedReturnsProposesNotInValidSpaces() throws {
        let (repo, _container) = try makeRepository()
        let validSpaceID = UUID()
        let orphanSpaceID = UUID()

        try repo.create(makePropose(spaceID: validSpaceID), spaceID: validSpaceID)
        try repo.create(makePropose(spaceID: orphanSpaceID), spaceID: orphanSpaceID)

        let orphaned = try repo.fetchAllOrphaned(validSpaceIDs: Set([validSpaceID]))
        #expect(orphaned.count == 1)
        #expect(orphaned[0].spaceID == orphanSpaceID)
    }

    // MARK: - Fetch by ID

    @Test func testFetchByIDThrowsWhenNotFound() throws {
        let (repo, _container) = try makeRepository()

        #expect(throws: ProposeRepositoryError.self) {
            try repo.fetch(by: UUID())
        }
    }

    // MARK: - Update

    @Test func testUpdateModifiesExistingPropose() throws {
        let (repo, _container) = try makeRepository()
        let id = UUID()
        let spaceID = UUID()
        let original = makePropose(id: id, spaceID: spaceID, message: "original")
        try repo.create(original, spaceID: spaceID)

        let updated = Propose(
            id: id,
            spaceID: spaceID,
            message: "updated",
            signatures: [],
            createdAt: original.createdAt,
            updatedAt: .now
        )
        try repo.update(updated)

        let fetched = try repo.fetch(by: id)
        #expect(fetched.message == "updated")
    }

    @Test func testUpdateAppendsNewSignatures() throws {
        let (repo, _container) = try makeRepository()
        let id = UUID()
        let spaceID = UUID()
        let sig1 = makeSignature(publicKey: "key1")
        let original = makePropose(id: id, spaceID: spaceID, signatures: [sig1])
        try repo.create(original, spaceID: spaceID)

        let sig2 = makeSignature(publicKey: "key2")
        let updated = Propose(
            id: id,
            spaceID: spaceID,
            message: original.message,
            signatures: [sig1, sig2],
            createdAt: original.createdAt,
            updatedAt: .now
        )
        try repo.update(updated)

        let fetched = try repo.fetch(by: id)
        #expect(fetched.signatures.count == 2)
    }

    @Test func testUpdateThrowsWhenProposeNotFound() throws {
        let (repo, _container) = try makeRepository()
        let propose = makePropose()

        #expect(throws: ProposeRepositoryError.self) {
            try repo.update(propose)
        }
    }

    // MARK: - Delete

    @Test func testDeleteRemovesPropose() throws {
        let (repo, _container) = try makeRepository()
        let spaceID = UUID()
        let propose = makePropose(spaceID: spaceID)
        try repo.create(propose, spaceID: spaceID)

        try repo.delete(by: propose.id)

        #expect(throws: ProposeRepositoryError.self) {
            try repo.fetch(by: propose.id)
        }
    }

    @Test func testDeleteThrowsWhenNotFound() throws {
        let (repo, _container) = try makeRepository()

        #expect(throws: ProposeRepositoryError.self) {
            try repo.delete(by: UUID())
        }
    }

    // MARK: - DeleteAll for SpaceID

    @Test func testDeleteAllForSpaceIDRemovesOnlyTargetSpaceProposes() throws {
        let (repo, _container) = try makeRepository()
        let spaceA = UUID()
        let spaceB = UUID()

        try repo.create(makePropose(spaceID: spaceA), spaceID: spaceA)
        try repo.create(makePropose(spaceID: spaceA), spaceID: spaceA)
        try repo.create(makePropose(spaceID: spaceB), spaceID: spaceB)

        try repo.deleteAll(for: spaceA)

        let all = try repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].spaceID == spaceB)
    }
}
