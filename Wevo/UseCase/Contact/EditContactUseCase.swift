//
//  EditContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol EditContactUseCase {
    func execute(id: UUID, nickname: String, publicKey: String) throws
}

struct EditContactUseCaseImpl {
    let contactRepository: ContactRepository
    let getContactUseCase: GetContactUseCase

    init(contactRepository: ContactRepository, getContactUseCase: GetContactUseCase) {
        self.contactRepository = contactRepository
        self.getContactUseCase = getContactUseCase
    }
}

extension EditContactUseCaseImpl: EditContactUseCase {
    func execute(id: UUID, nickname: String, publicKey: String) throws {
        let contact = try getContactUseCase.execute(id: id)

        let updated = Contact(
            id: contact.id,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            publicKey: publicKey.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: contact.createdAt
        )
        try contactRepository.update(updated)
    }
}
