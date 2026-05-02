//
//  CreateContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

enum CreateContactUseCaseError: Error {
    case duplicatePublicKey
}

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
        let trimmedPublicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = try contactRepository.fetchAll()
        guard !existing.contains(where: { $0.publicKey == trimmedPublicKey }) else {
            throw CreateContactUseCaseError.duplicatePublicKey
        }
        let contact = Contact(
            id: UUID(),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            publicKey: trimmedPublicKey,
            createdAt: .now
        )
        try contactRepository.create(contact)
    }
}
