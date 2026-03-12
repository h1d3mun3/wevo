//
//  ImportContactFromExportUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ImportContactFromExportUseCaseTests {

    @Test func testUsesSpecifiedNickname() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(
            publicKey:"SOME_PUBLIC_KEY",
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
        let exportData = ContactExportData(nickname: "Alice", publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(exportData: exportData, nickname: "  Alice  ")

        // Assert
        #expect(mockRepository.createdContact?.nickname == "Alice")
    }

    @Test func testAssignsNewUUIDToImportedContact() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(nickname: "Alice", publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(exportData: exportData, nickname: "Alice")

        // Assert
        #expect(mockRepository.createdContact?.id != nil)
    }

    @Test func testTwoImportsOfSameExportGetDifferentIDs() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let exportData = ContactExportData(nickname: "Alice", publicKey: "pk", exportedAt: .now)
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
        let exportData = ContactExportData(nickname: "Alice", publicKey: "pk", exportedAt: .now)
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(exportData: exportData, nickname: "Alice")
        }
    }
}
