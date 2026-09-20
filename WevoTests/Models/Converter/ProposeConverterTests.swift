//
//  ProposeConverterTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct ProposeConverterTests {

    private func makePropose(spaceID: UUID = UUID()) -> Propose {
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: "test message",
            creatorPublicKey: "creator-pub",
            creatorSignature: "creator-sig",
            counterpartyPublicKey: "counterparty-pub",
            counterpartySignSignature: "cp-sign-sig",
            counterpartySignTimestamp: "2026-01-01T00:00:00Z",
            creatorHonorSignature: "creator-honor-sig",
            creatorHonorTimestamp: "2026-01-02T00:00:00Z",
            signatureVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
    }

    @Test func testToEntityPreservesAllFields() {
        let id = UUID()
        let spaceID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        let updatedAt = Date(timeIntervalSince1970: 2000)
        let model = ProposeSwiftData(
            id: id,
            message: "hello",
            payloadHash: "hash",
            spaceID: spaceID,
            creatorPublicKey: "cpk",
            creatorSignature: "cs",
            counterpartyPublicKey: "cppk",
            counterpartySignSignature: "cpss",
            counterpartySignTimestamp: "ts1",
            signatureVersion: 1,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = ProposeConverter.toEntity(from: model)

        #expect(entity.id == id)
        #expect(entity.spaceID == spaceID)
        #expect(entity.message == "hello")
        #expect(entity.creatorPublicKey == "cpk")
        #expect(entity.creatorSignature == "cs")
        #expect(entity.counterpartyPublicKey == "cppk")
        #expect(entity.counterpartySignSignature == "cpss")
        #expect(entity.counterpartySignTimestamp == "ts1")
        #expect(entity.signatureVersion == 1)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test func testToModelPreservesAllFields() {
        let spaceID = UUID()
        let propose = makePropose(spaceID: spaceID)

        let model = ProposeConverter.toModel(from: propose, spaceID: spaceID)

        #expect(model.id == propose.id)
        #expect(model.spaceID == spaceID)
        #expect(model.message == propose.message)
        #expect(model.payloadHash == propose.payloadHash)
        #expect(model.creatorPublicKey == propose.creatorPublicKey)
        #expect(model.creatorSignature == propose.creatorSignature)
        #expect(model.counterpartyPublicKey == propose.counterpartyPublicKey)
        #expect(model.counterpartySignSignature == propose.counterpartySignSignature)
        #expect(model.counterpartySignTimestamp == propose.counterpartySignTimestamp)
        #expect(model.creatorHonorSignature == propose.creatorHonorSignature)
        #expect(model.creatorHonorTimestamp == propose.creatorHonorTimestamp)
        #expect(model.signatureVersion == propose.signatureVersion)
        #expect(model.createdAt == propose.createdAt)
        #expect(model.updatedAt == propose.updatedAt)
    }

    @Test func testToEntitiesConvertsAll() {
        let models = [
            ProposeSwiftData(id: UUID(), message: "m1", payloadHash: "h1", spaceID: UUID(),
                             creatorPublicKey: "k1", creatorSignature: "s1", counterpartyPublicKey: "cp1",
                             signatureVersion: 1, createdAt: .now, updatedAt: .now),
            ProposeSwiftData(id: UUID(), message: "m2", payloadHash: "h2", spaceID: UUID(),
                             creatorPublicKey: "k2", creatorSignature: "s2", counterpartyPublicKey: "cp2",
                             signatureVersion: 1, createdAt: .now, updatedAt: .now)
        ]

        let entities = ProposeConverter.toEntities(from: models)

        #expect(entities.count == 2)
        #expect(entities[0].message == "m1")
        #expect(entities[1].message == "m2")
    }

    @Test func testUpdateModelOverwritesMutableFields() {
        let spaceID = UUID()
        let model = ProposeSwiftData(
            id: UUID(), message: "old", payloadHash: "old-hash", spaceID: spaceID,
            creatorPublicKey: "cpk", creatorSignature: "cs", counterpartyPublicKey: "cppk",
            signatureVersion: 1, createdAt: .now, updatedAt: Date(timeIntervalSince1970: 0)
        )
        let updatedPropose = Propose(
            id: model.id, spaceID: spaceID,
            message: "new message",
            creatorPublicKey: "cpk", creatorSignature: "cs",
            counterpartyPublicKey: "cppk",
            counterpartySignSignature: "new-sig",
            signatureVersion: 1,
            createdAt: model.createdAt, updatedAt: .now
        )

        ProposeConverter.updateModel(model, with: updatedPropose)

        #expect(model.message == "new message")
        #expect(model.payloadHash == updatedPropose.payloadHash)
        #expect(model.counterpartySignSignature == "new-sig")
    }
}
