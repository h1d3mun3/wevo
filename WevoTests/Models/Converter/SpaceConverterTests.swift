//
//  SpaceConverterTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct SpaceConverterTests {

    private func makeSpace() -> Space {
        Space(
            id: UUID(),
            name: "Test Space",
            urls: ["https://node1.example.com", "https://node2.example.com"],
            defaultIdentityID: UUID(),
            orderIndex: 3,
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
    }

    @Test func testToEntityPreservesAllFields() {
        let id = UUID()
        let defaultID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        let updatedAt = Date(timeIntervalSince1970: 2000)
        let model = SpaceSwiftData(
            id: id,
            name: "My Space",
            nodeURLs: ["https://example.com"],
            defaultIdentityID: defaultID,
            orderIndex: 5,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = SpaceConverter.toEntity(from: model)

        #expect(entity.id == id)
        #expect(entity.name == "My Space")
        #expect(entity.urls == ["https://example.com"])
        #expect(entity.defaultIdentityID == defaultID)
        #expect(entity.orderIndex == 5)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test func testToModelPreservesAllFields() {
        let space = makeSpace()

        let model = SpaceConverter.toModel(from: space)

        #expect(model.id == space.id)
        #expect(model.name == space.name)
        #expect(model.nodeURLs == space.urls)
        #expect(model.defaultIdentityID == space.defaultIdentityID)
        #expect(model.orderIndex == space.orderIndex)
        #expect(model.createdAt == space.createdAt)
        #expect(model.updatedAt == space.updatedAt)
    }

    @Test func testToEntitiesConvertsAll() {
        let models = [
            SpaceSwiftData(id: UUID(), name: "A", nodeURLs: [], defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now),
            SpaceSwiftData(id: UUID(), name: "B", nodeURLs: [], defaultIdentityID: nil, orderIndex: 1, createdAt: .now, updatedAt: .now)
        ]

        let entities = SpaceConverter.toEntities(from: models)

        #expect(entities.count == 2)
        #expect(entities[0].name == "A")
        #expect(entities[1].name == "B")
    }

    @Test func testUpdateModelOverwritesMutableFields() {
        let model = SpaceSwiftData(
            id: UUID(), name: "Old Name", nodeURLs: ["https://old.com"],
            defaultIdentityID: nil, orderIndex: 0,
            createdAt: .now, updatedAt: Date(timeIntervalSince1970: 0)
        )
        let newID = UUID()
        let updatedSpace = Space(
            id: model.id, name: "New Name",
            urls: ["https://new1.com", "https://new2.com"],
            defaultIdentityID: newID, orderIndex: 7,
            createdAt: model.createdAt, updatedAt: .now
        )

        SpaceConverter.updateModel(model, with: updatedSpace)

        #expect(model.name == "New Name")
        #expect(model.nodeURLs == ["https://new1.com", "https://new2.com"])
        #expect(model.defaultIdentityID == newID)
        #expect(model.orderIndex == 7)
    }
}
