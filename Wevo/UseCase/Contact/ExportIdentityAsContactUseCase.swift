//
//  ExportIdentityAsContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol ExportIdentityAsContactUseCase {
    func execute(identity: Identity) throws -> URL
}

struct ExportIdentityAsContactUseCaseImpl: ExportIdentityAsContactUseCase {
    func execute(identity: Identity) throws -> URL {
        let exportData = ContactExportData(
            version: 1,
            publicKey: identity.publicKey,
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(exportData)
        let fileName = "contact-\(identity.id.uuidString).wevo-contact"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
