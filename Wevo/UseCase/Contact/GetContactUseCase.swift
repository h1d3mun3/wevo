//
//  GetContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol GetContactUseCase {
    func execute(id: UUID) throws -> Contact
}

struct GetContactUseCaseImpl {
    let contactRepository: ContactRepository

    init(contactRepository: ContactRepository) {
        self.contactRepository = contactRepository
    }
}

extension GetContactUseCaseImpl: GetContactUseCase {
    func execute(id: UUID) throws -> Contact {
        try contactRepository.fetch(by: id)
    }
}
