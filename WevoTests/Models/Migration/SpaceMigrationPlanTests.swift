//
//  SpaceMigrationPlanTests.swift
//  WevoTests
//

import Testing
import Foundation
import SwiftData
@testable import Wevo

/// Exercises `SpaceMigrationPlan` against real on-disk stores.
///
/// These tests deliberately avoid `isStoredInMemoryOnly`: a lightweight + custom stage chain only
/// runs when SwiftData opens a store file whose recorded version identifier is older than the
/// schema it is asked for, and an in-memory store is always created fresh at the target version.
@Suite(.serialized)
struct SpaceMigrationPlanTests {

    // MARK: - Store helpers

    /// Runs `body` against a store URL inside a directory unique to this test, removed afterwards.
    private func withTemporaryStore(_ body: (URL) throws -> Void) throws {
        let directory = URL.temporaryDirectory.appending(
            path: "SpaceMigrationPlanTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appending(path: "Wevo.store", directoryHint: .notDirectory))
    }

    /// Mirroring must stay off: `.automatic` picks up the test host's iCloud entitlement and
    /// attaches a CloudKit delegate that aborts the process from a background thread.
    private func configuration(url: URL, schema: Schema) -> ModelConfiguration {
        ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    }

    /// Creates the store at `url` at the given historical schema version and closes it again, so
    /// the next open finds that version recorded on disk and runs the stages above it.
    /// The container is scoped to this call so ARC releases the store before we reopen it.
    private func seed(
        _ versionedSchema: any VersionedSchema.Type,
        at url: URL,
        insert: (ModelContext) throws -> Void
    ) throws {
        let schema = Schema(versionedSchema: versionedSchema)
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration(url: url, schema: schema)]
        )
        let context = ModelContext(container)
        try insert(context)
        try context.save()
    }

    /// Opens the store at `url` at V3 through the full migration plan, exactly as the app does.
    private func openMigrated(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: SpaceMigrationPlan.self,
            configurations: [configuration(url: url, schema: schema)]
        )
    }

    private func migratedSpaces(at url: URL) throws -> [SpaceSwiftData] {
        let container = try openMigrated(at: url)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SpaceSwiftData>()
        descriptor.sortBy = [SortDescriptor(\.orderIndex)]
        return try context.fetch(descriptor)
    }

    // MARK: - Fixtures

    private func makeV1Space(
        id: UUID = UUID(),
        name: String = "V1 Space",
        urlString: String,
        orderIndex: Int = 0
    ) -> SchemaV1.SpaceSwiftData {
        SchemaV1.SpaceSwiftData(
            id: id,
            name: name,
            urlString: urlString,
            defaultIdentityID: nil,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeV2Space(
        id: UUID = UUID(),
        name: String = "V2 Space",
        urlString: String,
        nodeURLs: [String] = [],
        orderIndex: Int = 0
    ) -> SchemaV2.SpaceSwiftData {
        SchemaV2.SpaceSwiftData(
            id: id,
            name: name,
            urlString: urlString,
            nodeURLs: nodeURLs,
            defaultIdentityID: nil,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )
    }

    // MARK: - V1 → V2 → V3

    /// A store written by the original release (urlString only) must come out the far end of the
    /// whole stage chain with its URL carried into nodeURLs.
    @Test func testV1StoreMigratesURLStringIntoNodeURLs() throws {
        try withTemporaryStore { url in
            let id = UUID()
            try seed(SchemaV1.self, at: url) { context in
                context.insert(makeV1Space(id: id, name: "Legacy", urlString: "https://v1.example.com"))
            }

            let spaces = try migratedSpaces(at: url)

            #expect(spaces.count == 1)
            #expect(spaces.first?.id == id)
            #expect(spaces.first?.name == "Legacy")
            #expect(spaces.first?.nodeURLs == ["https://v1.example.com"])
        }
    }

    // MARK: - V2 → V3

    /// The load-bearing custom stage on its own: urlString set, nodeURLs still empty.
    @Test func testV2StoreWithEmptyNodeURLsMigratesURLString() throws {
        try withTemporaryStore { url in
            let id = UUID()
            try seed(SchemaV2.self, at: url) { context in
                context.insert(makeV2Space(id: id, urlString: "https://v2.example.com", nodeURLs: []))
            }

            let spaces = try migratedSpaces(at: url)

            #expect(spaces.count == 1)
            #expect(spaces.first?.id == id)
            #expect(spaces.first?.nodeURLs == ["https://v2.example.com"])
        }
    }

    /// A record that already carries nodeURLs was written by the multi-node build and is the source
    /// of truth; the migration must not overwrite it with the stale single urlString.
    @Test func testExistingNodeURLsAreNotClobbered() throws {
        try withTemporaryStore { url in
            let existing = ["https://primary.example.com", "https://peer.example.com"]
            try seed(SchemaV2.self, at: url) { context in
                context.insert(
                    makeV2Space(urlString: "https://stale.example.com", nodeURLs: existing)
                )
            }

            let spaces = try migratedSpaces(at: url)

            #expect(spaces.count == 1)
            #expect(spaces.first?.nodeURLs == existing)
        }
    }

    /// The other half of the willMigrate guard: nothing to copy, so nodeURLs stays empty rather
    /// than gaining an empty-string entry.
    @Test func testEmptyURLStringLeavesNodeURLsEmpty() throws {
        try withTemporaryStore { url in
            try seed(SchemaV2.self, at: url) { context in
                context.insert(makeV2Space(name: "No URL", urlString: "", nodeURLs: []))
            }

            let spaces = try migratedSpaces(at: url)

            #expect(spaces.count == 1)
            #expect(spaces.first?.name == "No URL")
            #expect(spaces.first?.nodeURLs.isEmpty == true)
        }
    }

    /// What `migrationMapping`'s keying by `id.uuidString` is actually for: each record must get
    /// back its own URL. A single-record test passes even if every record got the same value.
    @Test func testMultipleRecordsMigrateIndependently() throws {
        try withTemporaryStore { url in
            let ids = (0..<3).map { _ in UUID() }
            try seed(SchemaV2.self, at: url) { context in
                for (index, id) in ids.enumerated() {
                    context.insert(
                        makeV2Space(
                            id: id,
                            name: "Space \(index)",
                            urlString: "https://node\(index).example.com",
                            nodeURLs: [],
                            orderIndex: index
                        )
                    )
                }
            }

            let spaces = try migratedSpaces(at: url)

            #expect(spaces.count == 3)
            for (index, space) in spaces.enumerated() {
                #expect(space.id == ids[index])
                #expect(space.name == "Space \(index)")
                #expect(space.nodeURLs == ["https://node\(index).example.com"])
            }
        }
    }

    /// Mixed store: the three guard outcomes coexisting in one migration, which also proves the
    /// mapping does not leak a URL onto a record that did not ask for one.
    @Test func testMixedRecordsEachFollowTheirOwnGuardOutcome() throws {
        try withTemporaryStore { url in
            try seed(SchemaV2.self, at: url) { context in
                context.insert(
                    makeV2Space(name: "Needs copy", urlString: "https://copy.example.com", orderIndex: 0)
                )
                context.insert(
                    makeV2Space(
                        name: "Already migrated",
                        urlString: "https://stale.example.com",
                        nodeURLs: ["https://kept.example.com"],
                        orderIndex: 1
                    )
                )
                context.insert(
                    makeV2Space(name: "Nothing to copy", urlString: "", orderIndex: 2)
                )
            }

            let spaces = try migratedSpaces(at: url)

            #expect(spaces.count == 3)
            #expect(spaces.first { $0.name == "Needs copy" }?.nodeURLs == ["https://copy.example.com"])
            #expect(spaces.first { $0.name == "Already migrated" }?.nodeURLs == ["https://kept.example.com"])
            #expect(spaces.first { $0.name == "Nothing to copy" }?.nodeURLs.isEmpty == true)
        }
    }
}
