//
//  ImportContactFromExportUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
import CryptoKit
@testable import Wevo

@MainActor
struct ImportContactFromExportUseCaseTests {

    private func writeTemp(_ export: ContactExportData) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("contact-\(UUID()).wevo-contact")
        try encoder.encode(export).write(to: url)
        return url
    }

    @Test func testUsesSpecifiedNickname() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(
            version: 1,
            publicKey: "SOME_PUBLIC_KEY",
            exportedAt: .now
        )
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(exportData: exportData, nickname: "Alice")

        // Assert
        #expect(mockRepository.createCalled == true)
        #expect(mockRepository.createdContact?.nickname == "Alice")
        #expect(mockRepository.createdContact?.publicKey == "SOME_PUBLIC_KEY")
    }

    @Test func testTrimsNickname() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(version: 1, publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(exportData: exportData, nickname: "  Alice  ")

        // Assert
        #expect(mockRepository.createdContact?.nickname == "Alice")
    }

    @Test func testAssignsNewUUIDToImportedContact() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(version: 1, publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(exportData: exportData, nickname: "Alice")

        // Assert
        #expect(mockRepository.createdContact?.id != nil)
    }

    @Test func testTwoImportsOfSameExportGetDifferentIDs() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(version: 1, publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(exportData: exportData, nickname: "Alice")
        let firstID = mockRepository.createdContact?.id

        try useCase.execute(exportData: exportData, nickname: "Alice")
        let secondID = mockRepository.createdContact?.id

        // Assert
        #expect(firstID != secondID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.createError = NSError(domain: "Test", code: -1)
        let exportData = ContactExportData(version: 1, publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(exportData: exportData, nickname: "Alice")
        }
    }

    // MARK: - readFromFile validation

    @Test func testReadFromFileRejectsInvalidPublicKey() throws {
        let url = try writeTemp(ContactExportData(version: 1, publicKey: "not-a-jwk", exportedAt: .now))
        defer { try? FileManager.default.removeItem(at: url) }
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: MockContactRepository())

        #expect(throws: ImportContactFromExportUseCaseError.invalidPublicKey) {
            _ = try useCase.readFromFile(url: url)
        }
    }

    @Test func testReadFromFileRejectsUnsupportedVersion() throws {
        let jwk = P256.Signing.PrivateKey().publicKey.jwkString
        let url = try writeTemp(ContactExportData(version: 999, publicKey: jwk, exportedAt: .now))
        defer { try? FileManager.default.removeItem(at: url) }
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: MockContactRepository())

        #expect(throws: ImportContactFromExportUseCaseError.unsupportedVersion) {
            _ = try useCase.readFromFile(url: url)
        }
    }

    @Test func testReadFromFileAcceptsValidContact() throws {
        let jwk = P256.Signing.PrivateKey().publicKey.jwkString
        let url = try writeTemp(ContactExportData(version: 1, publicKey: jwk, exportedAt: .now))
        defer { try? FileManager.default.removeItem(at: url) }
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: MockContactRepository())

        let read = try useCase.readFromFile(url: url)
        #expect(read.publicKey == jwk)
    }
}
