//
//  SignatureRepositoryTests.swift
//  WevoTests
//

import Testing
import Foundation
import SwiftData
@testable import Wevo

@Suite(.serialized)
@MainActor
struct SignatureRepositoryTests {

    private func makeContext() throws -> (ModelContext, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SpaceSwiftData.self, ProposeSwiftData.self, SignatureSwiftData.self,
            configurations: config
        )
        return (container.mainContext, container)
    }

    private func insertPropose(
        context: ModelContext,
        proposeID: UUID = UUID(),
        spaceID: UUID = UUID(),
        message: String = "test",
        signatures: [SignatureSwiftData] = []
    ) -> ProposeSwiftData {
        let model = ProposeSwiftData(
            id: proposeID,
            message: message,
            payloadHash: message,
            spaceID: spaceID,
            signatures: signatures,
            createdAt: .now,
            updatedAt: .now
        )
        context.insert(model)
        try? context.save()
        return model
    }

    private func makeSignatureModel(
        id: UUID = UUID(),
        publicKey: String = "pk",
        signatureData: String = "sig"
    ) -> SignatureSwiftData {
        SignatureSwiftData(id: id, publicKey: publicKey, signatureData: signatureData, createdAt: .now)
    }

    // MARK: - FetchAll

    @Test func testFetchAllReturnsAllSignatures() throws {
        let (context, _container) = try makeContext()
        let sig1 = makeSignatureModel(publicKey: "key1")
        let sig2 = makeSignatureModel(publicKey: "key2")
        _ = insertPropose(context: context, signatures: [sig1, sig2])

        let repo = SignatureRepositoryImpl(modelContext: context)
        let all = try repo.fetchAll()

        #expect(all.count == 2)
    }

    @Test func testFetchAllReturnsEmptyWhenNoSignatures() throws {
        let (context, _container) = try makeContext()
        let repo = SignatureRepositoryImpl(modelContext: context)
        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }

    // MARK: - Delete

    @Test func testDeleteRemovesSignature() throws {
        let (context, _container) = try makeContext()
        let sigID = UUID()
        let sig = makeSignatureModel(id: sigID)
        _ = insertPropose(context: context, signatures: [sig])

        let repo = SignatureRepositoryImpl(modelContext: context)
        try repo.delete(by: sigID)

        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test func testDeleteThrowsWhenNotFound() throws {
        let (context, _container) = try makeContext()
        let repo = SignatureRepositoryImpl(modelContext: context)

        #expect(throws: SignatureRepositoryError.self) {
            try repo.delete(by: UUID())
        }
    }

    // MARK: - FetchPayloadHash

    @Test func testFetchPayloadHashReturnsCorrectHash() throws {
        let (context, _container) = try makeContext()
        let sigID = UUID()
        let sig = makeSignatureModel(id: sigID)
        _ = insertPropose(context: context, message: "hello", signatures: [sig])

        let repo = SignatureRepositoryImpl(modelContext: context)
        let hash = try repo.fetchPayloadHash(forSignatureID: sigID)

        #expect(hash == "hello")
    }

    @Test func testFetchPayloadHashThrowsWhenSignatureNotFound() throws {
        let (context, _container) = try makeContext()
        let repo = SignatureRepositoryImpl(modelContext: context)

        #expect(throws: SignatureRepositoryError.self) {
            try repo.fetchPayloadHash(forSignatureID: UUID())
        }
    }
}
