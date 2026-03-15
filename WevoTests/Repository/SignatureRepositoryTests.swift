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

    /// Helper to insert SignatureSwiftData directly into context
    /// In the new API, there is no relation between SignatureSwiftData and ProposeSwiftData
    private func insertSignature(
        context: ModelContext,
        id: UUID = UUID(),
        publicKey: String = "pk",
        signatureData: String = "sig"
    ) -> SignatureSwiftData {
        let model = SignatureSwiftData(
            id: id,
            publicKey: publicKey,
            signatureData: signatureData,
            createdAt: .now
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
        // Insert 2 Signatures directly
        _ = insertSignature(context: context, publicKey: "key1")
        _ = insertSignature(context: context, publicKey: "key2")

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
        _ = insertSignature(context: context, id: sigID)

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
    // In the new API, since there is no relation between SignatureSwiftData and ProposeSwiftData,
    // fetchPayloadHash always throws an error

    @Test func testFetchPayloadHashThrowsWhenSignatureNotFound() throws {
        let (context, _container) = try makeContext()
        let repo = SignatureRepositoryImpl(modelContext: context)

        // In the new API, always throws proposeNotFoundForSignature
        #expect(throws: SignatureRepositoryError.self) {
            try repo.fetchPayloadHash(forSignatureID: UUID())
        }
    }

    @Test func testFetchPayloadHashAlwaysThrows() throws {
        let (context, _container) = try makeContext()
        let sigID = UUID()
        // Insert Signature directly into Context (no relation to Propose)
        _ = insertSignature(context: context, id: sigID)

        let repo = SignatureRepositoryImpl(modelContext: context)

        // In the new API, always errors because there is no relation
        #expect(throws: SignatureRepositoryError.self) {
            try repo.fetchPayloadHash(forSignatureID: sigID)
        }
    }
}
