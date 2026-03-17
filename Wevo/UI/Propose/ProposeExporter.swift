//
//  ProposeExporter.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import UniformTypeIdentifiers
import os

/// Wrapper for exporting a Propose
struct ProposeExportData: Codable {
    let propose: Propose
    let spaceID: UUID
    let spaceName: String
    let exportedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case propose
        case spaceID = "spaceId"
        case spaceName = "spaceName"
        case exportedAt = "exportedAt"
    }
}

/// Manages Propose export and AirDrop sharing
struct ProposeExporter {
    
    /// Exports a Propose in JSON format and returns a shareable URL
    static func exportPropose(_ propose: Propose, space: Space) throws -> URL {
        let exportData = ProposeExportData(
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
        
        // Save file to the temporary directory
        // Using custom extension .wevo-propose
        let fileName = "propose-\(propose.id.uuidString).wevo-propose"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try jsonData.write(to: tempURL)
        
        Logger.propose.debug("Propose exported to: \(tempURL.path, privacy: .private)")
        
        return tempURL
    }
    
    /// Import a Propose from a JSON file
    static func importPropose(from url: URL) throws -> ProposeExportData {
        let jsonData = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ProposeAPIClient.iso8601Formatter.date(from: string)
                ?? ProposeAPIClient.iso8601FormatterBasic.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
        }
        
        let exportData = try decoder.decode(ProposeExportData.self, from: jsonData)
        
        Logger.propose.debug("Propose imported from: \(url.path, privacy: .private)")
        
        return exportData
    }
}

// Note: The Transferable implementation is kept for future extension
// Currently, file sharing is done using ShareSheet
