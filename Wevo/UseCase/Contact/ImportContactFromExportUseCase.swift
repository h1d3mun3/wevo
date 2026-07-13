//
//  ImportContactFromExportUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation
import CryptoKit

enum ImportContactFromExportUseCaseError: Error, LocalizedError {
    case unsupportedVersion
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "Unsupported contact file version."
        case .invalidPublicKey: return "The contact file does not contain a valid P-256 public key."
        }
    }
}

protocol ImportContactFromExportUseCase {
    func readFromFile(url: URL) throws -> ContactExportData
    func execute(exportData: ContactExportData, nickname: String) throws
}

struct ImportContactFromExportUseCaseImpl: ImportContactFromExportUseCase {
    let contactRepository: ContactRepository

    static let supportedVersion = 1

    func readFromFile(url: URL) throws -> ContactExportData {
        let data = try readImportData(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(ContactExportData.self, from: data)
        // Validate the untrusted file before it can be stored.
        guard export.version == Self.supportedVersion else {
            throw ImportContactFromExportUseCaseError.unsupportedVersion
        }
        guard P256.Signing.PublicKey.fromJWKString(export.publicKey) != nil else {
            throw ImportContactFromExportUseCaseError.invalidPublicKey
        }
        return export
    }

    func execute(exportData: ContactExportData, nickname: String) throws {
        let contact = Contact(
            id: UUID(),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            publicKey: exportData.publicKey,
            createdAt: .now
        )
        try contactRepository.create(contact)
    }
}
