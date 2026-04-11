//
//  SpaceMigrationPlan.swift
//  Wevo
//
//  Created on 4/6/26.
//

import Foundation
import SwiftData

// MARK: - V1 Schema
// Original schema: urlString only, no nodeURLs.
// Matches stores created from the main branch.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.SpaceSwiftData.self, ProposeSwiftData.self, ContactSwiftData.self]
    }

    @Model
    final class SpaceSwiftData {
        var id: UUID = UUID()
        var name: String = ""
        var urlString: String = ""
        var defaultIdentityID: UUID?
        var orderIndex: Int = 0
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        init(
            id: UUID,
            name: String,
            urlString: String,
            defaultIdentityID: UUID?,
            orderIndex: Int,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.name = name
            self.urlString = urlString
            self.defaultIdentityID = defaultIdentityID
            self.orderIndex = orderIndex
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - V2 Schema
// Intermediate schema: both urlString and nodeURLs present.
// Matches stores on devices that ran the multi-node feature branch before this migration was introduced.

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV2.SpaceSwiftData.self, ProposeSwiftData.self, ContactSwiftData.self]
    }

    @Model
    final class SpaceSwiftData {
        var id: UUID = UUID()
        var name: String = ""
        var urlString: String = ""
        var nodeURLs: [String] = []
        var defaultIdentityID: UUID?
        var orderIndex: Int = 0
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        init(
            id: UUID,
            name: String,
            urlString: String,
            nodeURLs: [String],
            defaultIdentityID: UUID?,
            orderIndex: Int,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.name = name
            self.urlString = urlString
            self.nodeURLs = nodeURLs
            self.defaultIdentityID = defaultIdentityID
            self.orderIndex = orderIndex
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - V3 Schema
// Target schema: nodeURLs only, urlString removed.

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SpaceSwiftData.self, ProposeSwiftData.self, ContactSwiftData.self]
    }
}

// MARK: - Migration Plan

enum SpaceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }
    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }

    /// V1 → V2: lightweight — nodeURLs is added with default [].
    private static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    /// Temporary in-memory store to pass urlString values from willMigrate to didMigrate.
    /// Cleared immediately after didMigrate completes.
    private static var migrationMapping: [String: String] = [:]

    /// V2 → V3: custom — copies urlString → nodeURLs[0] for records where nodeURLs is still empty,
    /// then urlString is dropped as part of the schema change.
    private static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self,
        willMigrate: { context in
            let spaces = try context.fetch(FetchDescriptor<SchemaV2.SpaceSwiftData>())
            for space in spaces where !space.urlString.isEmpty && space.nodeURLs.isEmpty {
                migrationMapping[space.id.uuidString] = space.urlString
            }
        },
        didMigrate: { context in
            let spaces = try context.fetch(FetchDescriptor<SpaceSwiftData>())
            for space in spaces {
                if let urlString = migrationMapping[space.id.uuidString] {
                    space.nodeURLs = [urlString]
                }
            }
            try context.save()
            migrationMapping = [:]
        }
    )
}
