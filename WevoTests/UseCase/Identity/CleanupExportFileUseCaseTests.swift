//
//  CleanupExportFileUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct CleanupExportFileUseCaseTests {

    @Test func testDeletesExistingFiles() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
        let url1 = tempDir.appendingPathComponent(UUID().uuidString)
        let url2 = tempDir.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url1.path, contents: Data())
        FileManager.default.createFile(atPath: url2.path, contents: Data())
        let useCase = CleanupExportFileUseCaseImpl()

        // Act
        useCase.execute(urls: [url1, url2])

        // Assert
        #expect(FileManager.default.fileExists(atPath: url1.path) == false)
        #expect(FileManager.default.fileExists(atPath: url2.path) == false)
    }

    @Test func testIgnoresNilURLs() {
        // Arrange
        let useCase = CleanupExportFileUseCaseImpl()

        // Act & Assert: nil が混在しても crash しない
        useCase.execute(urls: [nil, nil])
    }

    @Test func testIgnoresNonExistentURLs() {
        // Arrange
        let nonExistent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let useCase = CleanupExportFileUseCaseImpl()

        // Act & Assert: 存在しないファイルでも throw しない
        useCase.execute(urls: [nonExistent])
    }

    @Test func testHandlesMixedNilAndValidURLs() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        let useCase = CleanupExportFileUseCaseImpl()

        // Act
        useCase.execute(urls: [nil, url, nil])

        // Assert
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }
}
