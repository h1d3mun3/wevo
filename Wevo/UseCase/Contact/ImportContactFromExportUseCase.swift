//
//  ImportContactFromExportUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol ImportContactFromExportUseCase {
    func execute(exportData: ContactExportData, nickname: String) throws
}

struct ImportContactFromExportUseCaseImpl: ImportContactFromExportUseCase {
    let contactRepository: ContactRepository

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
