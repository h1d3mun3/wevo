//
//  ContactTransfer.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

struct ContactExportData: Codable {
    let version: Int
    let publicKey: String // JWK format
    let exportedAt: Date
}

enum ContactTransfer {
    static func exportToFile(identity: Identity) throws -> URL {
        let exportData = ContactExportData(
            version: 1,
            publicKey: identity.publicKey,
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(exportData)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "contact-\(identity.id.uuidString).wevo-contact"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func importFromFile(url: URL) throws -> ContactExportData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ContactExportData.self, from: data)
    }
}
