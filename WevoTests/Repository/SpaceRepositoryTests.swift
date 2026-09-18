//
//  SpaceRepositoryTests.swift
//  WevoTests
//

import Testing
import Foundation
import SwiftData
@testable import Wevo

@Suite(.serialized)
@MainActor
struct SpaceRepositoryTests {

    /// The container is held for the lifetime of the suite instance. `ModelContext` does not keep
    /// its `ModelContainer` alive, so letting the container go out of scope tears down the store
    /// coordinator and the next repository call raises an uncaught CoreData exception, aborting the
    /// whole test process. swift-testing builds a fresh instance per test, so each test still gets
    /// its own store.
    let container: ModelContainer
    let repo: SpaceRepositoryImpl

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: SpaceSwiftData.self, ProposeSwiftData.self,
            configurations: config
        )
        repo = SpaceRepositoryImpl(modelContext: container.mainContext)
    }

    private func makeSpace(
        id: UUID = UUID(),
        name: String = "Test Space",
        url: String = "https://example.com",
        orderIndex: Int = 0
    ) -> Space {
        Space(
            id: id,
            name: name,
            url: url,
            defaultIdentityID: nil,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )
    }

    // MARK: - Create

    @Test func testCreateAndFetchSpace() throws {
        let space = makeSpace()

        try repo.create(space)
        let fetched = try repo.fetch(by: space.id)

        #expect(fetched.id == space.id)
        #expect(fetched.name == space.name)
        #expect(fetched.url == space.url)
    }

    // MARK: - FetchAll

    @Test func testFetchAllReturnsAllSpacesSortedByOrderIndex() throws {
        let space1 = makeSpace(name: "B", orderIndex: 1)
        let space2 = makeSpace(name: "A", orderIndex: 0)

        try repo.create(space1)
        try repo.create(space2)

        let all = try repo.fetchAll()
        #expect(all.count == 2)
        #expect(all[0].name == "A")
        #expect(all[1].name == "B")
    }

    @Test func testFetchAllReturnsEmptyWhenNoSpaces() throws {
        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }

    // MARK: - Fetch by ID

    @Test func testFetchByIDThrowsWhenNotFound() throws {

        #expect(throws: SpaceRepositoryError.self) {
            try repo.fetch(by: UUID())
        }
    }

    // MARK: - Update

    @Test func testUpdateModifiesExistingSpace() throws {
        let id = UUID()
        let original = makeSpace(id: id, name: "Original")
        try repo.create(original)

        let updated = Space(
            id: id,
            name: "Updated",
            url: "https://updated.com",
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: original.createdAt,
            updatedAt: .now
        )
        try repo.update(updated)

        let fetched = try repo.fetch(by: id)
        #expect(fetched.name == "Updated")
        #expect(fetched.url == "https://updated.com")
    }

    @Test func testUpdateThrowsWhenSpaceNotFound() throws {
        let space = makeSpace()

        #expect(throws: SpaceRepositoryError.self) {
            try repo.update(space)
        }
    }

    // MARK: - Delete

    @Test func testDeleteRemovesSpace() throws {
        let space = makeSpace()
        try repo.create(space)

        try repo.delete(by: space.id)

        #expect(throws: SpaceRepositoryError.self) {
            try repo.fetch(by: space.id)
        }
    }

    @Test func testDeleteThrowsWhenNotFound() throws {

        #expect(throws: SpaceRepositoryError.self) {
            try repo.delete(by: UUID())
        }
    }

    // MARK: - DeleteAll

    @Test func testDeleteAllRemovesAllSpaces() throws {
        try repo.create(makeSpace(orderIndex: 0))
        try repo.create(makeSpace(orderIndex: 1))

        try repo.deleteAll()

        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }
}
