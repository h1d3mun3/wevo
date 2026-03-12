//
//  CreateContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol CreateContactUseCase {
    func execute(nickname: String, publicKey: String) throws
}

struct CreateContactUseCaseImpl {
    let contactRepository: ContactRepository

    init(contactRepository: ContactRepository) {
        self.contactRepository = contactRepository
    }
}

extension CreateContactUseCaseImpl: CreateContactUseCase {
    func execute(nickname: String, publicKey: String) throws {
        let contact = Contact(
            id: UUID(),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            publicKey: publicKey.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: .now
        )
        try contactRepository.create(contact)
    }
}
