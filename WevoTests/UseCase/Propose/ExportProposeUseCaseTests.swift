//
//  ExportProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ExportProposeUseCaseTests {

    let space = Space(
        id: UUID(),
        name: "Test Space",
        url: "https://example.com",
        defaultIdentityID: nil,
        orderIndex: 0,
        createdAt: .now,
        updatedAt: .now
    )

    let propose = Propose(
        id: UUID(),
        spaceID: UUID(),
        message: "Test message",
        creatorPublicKey: "creatorKey",
        creatorSignature: "creatorSig",
        counterpartyPublicKey: "counterpartyKey",
        counterpartySignSignature: nil,
        createdAt: .now,
        updatedAt: .now
    )

    @Test("Can export Propose to a JSON file")
    func executeSuccess() throws {
        let useCase = ExportProposeUseCaseImpl()
        let url = try useCase.execute(propose: propose, space: space)

        #expect(url.pathExtension == "wevo-propose")
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Export file contains Propose data")
    func exportContainsProposeData() throws {
        let useCase = ExportProposeUseCaseImpl()
        let url = try useCase.execute(propose: propose, space: space)

        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8)!
        #expect(content.contains(propose.message))
        #expect(content.contains(space.name))

        try? FileManager.default.removeItem(at: url)
    }

    @Test("Import of exported file yields the same data")
    func exportImportRoundTrip() throws {
        let exportUseCase = ExportProposeUseCaseImpl()
        let url = try exportUseCase.execute(propose: propose, space: space)

        let mockKeychainRepository = MockKeychainRepository()
        let mockProposeRepository = MockProposeRepository()
        let importUseCase = ImportProposeUseCaseImpl(proposeRepository: mockProposeRepository, keychainRepository: mockKeychainRepository)
        let imported = try importUseCase.readFromFile(url: url)
        #expect(imported.propose.id == propose.id)
        #expect(imported.propose.message == propose.message)
        #expect(imported.spaceName == space.name)
        #expect(imported.spaceID == space.id)

        try? FileManager.default.removeItem(at: url)
    }
}
