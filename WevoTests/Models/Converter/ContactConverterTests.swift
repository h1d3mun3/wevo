//
//  ContactConverterTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct ContactConverterTests {

    @Test func testToEntityPreservesAllFields() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        let model = ContactSwiftData(id: id, nickname: "Alice", publicKey: "jwk-key", createdAt: createdAt)

        let entity = ContactConverter.toEntity(from: model)

        #expect(entity.id == id)
        #expect(entity.nickname == "Alice")
        #expect(entity.publicKey == "jwk-key")
        #expect(entity.createdAt == createdAt)
    }

    @Test func testToModelPreservesAllFields() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        let contact = Contact(id: id, nickname: "Bob", publicKey: "jwk-bob", createdAt: createdAt)

        let model = ContactConverter.toModel(from: contact)

        #expect(model.id == id)
        #expect(model.nickname == "Bob")
        #expect(model.publicKey == "jwk-bob")
        #expect(model.createdAt == createdAt)
    }

    @Test func testToEntitiesConvertsAll() {
        let models = [
            ContactSwiftData(id: UUID(), nickname: "Alice", publicKey: "key-a", createdAt: .now),
            ContactSwiftData(id: UUID(), nickname: "Bob", publicKey: "key-b", createdAt: .now)
        ]

        let entities = ContactConverter.toEntities(from: models)

        #expect(entities.count == 2)
        #expect(entities[0].nickname == "Alice")
        #expect(entities[1].nickname == "Bob")
    }

    @Test func testUpdateModelOverwritesMutableFields() {
        let model = ContactSwiftData(id: UUID(), nickname: "Old", publicKey: "old-key", createdAt: .now)
        let updatedContact = Contact(id: model.id, nickname: "New", publicKey: "new-key", createdAt: model.createdAt)

        ContactConverter.updateModel(model, with: updatedContact)

        #expect(model.nickname == "New")
        #expect(model.publicKey == "new-key")
    }
}
