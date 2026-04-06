//
//  ExportProposeUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

protocol ExportProposeUseCase {
    func execute(propose: Propose, space: Space) throws -> URL
}

struct ExportProposeUseCaseImpl: ExportProposeUseCase {
    func execute(propose: Propose, space: Space) throws -> URL {
        let exportData = ProposeExportData(
            version: 1,
            propose: propose,
            spaceID: space.id,
            spaceName: space.name,
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ProposeAPIClient.iso8601Formatter.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportData)
        let fileName = "propose-\(propose.id.uuidString).wevo-propose"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try jsonData.write(to: tempURL)
        Logger.propose.debug("Propose exported to: \(tempURL.path, privacy: .private)")
        return tempURL
    }
}
