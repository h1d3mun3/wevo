//
//  SignatureRepository.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import SwiftData

enum SignatureRepositoryError: Error {
    case signatureNotFound(UUID)
    case proposeNotFoundForSignature(UUID)
    case deleteError(Error)
    case fetchError(Error)
}

@MainActor
protocol SignatureRepository {
    func fetchAll() throws -> [Signature]
    func delete(by id: UUID) throws
    func fetchPayloadHash(forSignatureID id: UUID) throws -> String
}

/// SwiftDataを使用してSignatureの操作を提供するRepository
final class SignatureRepositoryImpl: SignatureRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    /// すべてのSignatureを取得（作成日時の降順でソート）
    func fetchAll() throws -> [Signature] {
        let descriptor = FetchDescriptor<SignatureSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            // SignatureSwiftDataをSignatureエンティティに変換
            return models.map { model in
                Signature(
                    id: model.id,
                    publicKey: model.publicKey,
                    signature: model.signatureData,
                    createdAt: model.createdAt
                )
            }
        } catch {
            throw SignatureRepositoryError.fetchError(error)
        }
    }

    // MARK: - Delete

    func delete(by id: UUID) throws {
        let predicate = #Predicate<SignatureSwiftData> { model in
            model.id == id
        }

        var descriptor = FetchDescriptor<SignatureSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw SignatureRepositoryError.signatureNotFound(id)
            }

            modelContext.delete(model)
            try modelContext.save()
        } catch let error as SignatureRepositoryError {
            throw error
        } catch {
            throw SignatureRepositoryError.deleteError(error)
        }
    }

    // MARK: - Fetch

    /// 署名IDに紐づくProposeのpayloadHashを取得
    /// 新APIではSignatureSwiftDataとProposeSwiftDataのリレーションがないため、
    /// 常にSignatureRepositoryError.proposeNotFoundForSignatureをスローする
    /// （この機能は新APIでは使用されない）
    func fetchPayloadHash(forSignatureID id: UUID) throws -> String {
        throw SignatureRepositoryError.proposeNotFoundForSignature(id)
    }
}
