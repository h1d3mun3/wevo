//
//  ExportProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

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

    @Test("ProposeをJSONファイルにエクスポートできる")
    func executeSuccess() throws {
        let useCase = ExportProposeUseCaseImpl()
        let url = try useCase.execute(propose: propose, space: space)

        #expect(url.pathExtension == "wevo-propose")
        #expect(FileManager.default.fileExists(atPath: url.path))

        // クリーンアップ
        try? FileManager.default.removeItem(at: url)
    }

    @Test("エクスポートファイルにProposeデータが含まれる")
    func exportContainsProposeData() throws {
        let useCase = ExportProposeUseCaseImpl()
        let url = try useCase.execute(propose: propose, space: space)

        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8)!
        #expect(content.contains(propose.message))
        #expect(content.contains(space.name))

        try? FileManager.default.removeItem(at: url)
    }

    @Test("エクスポートファイルをインポートして同じデータが得られる")
    func exportImportRoundTrip() throws {
        let useCase = ExportProposeUseCaseImpl()
        let url = try useCase.execute(propose: propose, space: space)

        let imported = try ProposeExporter.importPropose(from: url)
        #expect(imported.propose.id == propose.id)
        #expect(imported.propose.message == propose.message)
        #expect(imported.spaceName == space.name)
        #expect(imported.spaceID == space.id)

        try? FileManager.default.removeItem(at: url)
    }
}
