//
//  ImportContactFromExportUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol ImportContactFromExportUseCase {
    func readFromFile(url: URL) throws -> ContactExportData
    func execute(exportData: ContactExportData, nickname: String) throws
}

struct ImportContactFromExportUseCaseImpl: ImportContactFromExportUseCase {
    let contactRepository: ContactRepository

    func readFromFile(url: URL) throws -> ContactExportData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ContactExportData.self, from: data)
    }

    func execute(exportData: ContactExportData, nickname: String) throws {
        let contact = Contact(
            id: UUID(),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            publicKey: exportData.publicKey,
            createdAt: .now
        )
        try contactRepository.create(contact)
    }
}
