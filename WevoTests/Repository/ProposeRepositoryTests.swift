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
        creatorPublicKey: String = "creatorKey",
        counterpartyPublicKey: String = "counterpartyKey",
        counterpartySignSignature: String? = nil
    ) -> Propose {
        Propose(
            id: id,
            spaceID: spaceID,
            message: message,
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
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

    @Test func testCreateProposeWithCreatorAndCounterpartyKeys() throws {
        let (repo, _container) = try makeRepository()
        let spaceID = UUID()
        let propose = makePropose(
            spaceID: spaceID,
            creatorPublicKey: "aliceKey",
            counterpartyPublicKey: "bobKey"
        )

        try repo.create(propose, spaceID: spaceID)
        let fetched = try repo.fetch(by: propose.id)

        #expect(fetched.creatorPublicKey == "aliceKey")
        #expect(fetched.counterpartyPublicKey == "bobKey")
        #expect(fetched.counterpartySignSignature == nil)
    }

    @Test func testCreateProposeWithCounterpartySignature() throws {
        let (repo, _container) = try makeRepository()
        let spaceID = UUID()
        let propose = makePropose(spaceID: spaceID, counterpartySignSignature: "counterpartySig")

        try repo.create(propose, spaceID: spaceID)
        let fetched = try repo.fetch(by: propose.id)

        #expect(fetched.counterpartySignSignature == "counterpartySig")
        #expect(fetched.localStatus == .signed)
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
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: original.createdAt,
            updatedAt: .now
        )
        try repo.update(updated)

        let fetched = try repo.fetch(by: id)
        #expect(fetched.message == "updated")
    }

    @Test func testUpdateSetsCounterpartySignSignature() throws {
        let (repo, _container) = try makeRepository()
        let id = UUID()
        let spaceID = UUID()
        let original = makePropose(id: id, spaceID: spaceID, counterpartySignSignature: nil)
        try repo.create(original, spaceID: spaceID)

        // counterpartySignSignatureをセットして更新
        let updated = Propose(
            id: id,
            spaceID: spaceID,
            message: original.message,
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: "newSig",
            createdAt: original.createdAt,
            updatedAt: .now
        )
        try repo.update(updated)

        let fetched = try repo.fetch(by: id)
        #expect(fetched.counterpartySignSignature == "newSig")
        #expect(fetched.localStatus == .signed)
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
