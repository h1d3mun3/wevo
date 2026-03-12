//
//  ExportIdentityAsContactUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ExportIdentityAsContactUseCaseTests {

    let identity = Identity(
        id: UUID(),
        nickname: "Alice",
        publicKey: "SAMPLE_PUBLIC_KEY"
    )

    @Test func testExportsToWevoContactFile() throws {
        let useCase = ExportIdentityAsContactUseCaseImpl()

        let url = try useCase.execute(identity: identity)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "wevo-contact")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func testExportedFileContainsCorrectPublicKey() throws {
        let useCase = ExportIdentityAsContactUseCaseImpl()

        let url = try useCase.execute(identity: identity)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(ContactExportData.self, from: data)

        #expect(exported.publicKey == identity.publicKey)
    }

    @Test func testExportedFileIsValidJSON() throws {
        let useCase = ExportIdentityAsContactUseCaseImpl()

        let url = try useCase.execute(identity: identity)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }
}
