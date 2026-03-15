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

    /// SignatureSwiftDataを直接contextに挿入するヘルパー
    /// 新APIではSignatureSwiftDataとProposeSwiftDataのリレーションはない
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
        // 2件のSignatureを直接insertする
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
    // 新APIではSignatureSwiftDataとProposeSwiftDataのリレーションがないため、
    // fetchPayloadHashは常にエラーをスローする

    @Test func testFetchPayloadHashThrowsWhenSignatureNotFound() throws {
        let (context, _container) = try makeContext()
        let repo = SignatureRepositoryImpl(modelContext: context)

        // 新APIでは常にproposeNotFoundForSignatureをスローする
        #expect(throws: SignatureRepositoryError.self) {
            try repo.fetchPayloadHash(forSignatureID: UUID())
        }
    }

    @Test func testFetchPayloadHashAlwaysThrows() throws {
        let (context, _container) = try makeContext()
        let sigID = UUID()
        // SignatureをContextに直接insert（Proposeとのリレーションなし）
        _ = insertSignature(context: context, id: sigID)

        let repo = SignatureRepositoryImpl(modelContext: context)

        // 新APIではリレーションがないため常にエラー
        #expect(throws: SignatureRepositoryError.self) {
            try repo.fetchPayloadHash(forSignatureID: sigID)
        }
    }
}
