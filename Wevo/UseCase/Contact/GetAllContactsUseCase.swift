//
//  GetAllContactsUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol GetAllContactsUseCase {
    func execute() throws -> [Contact]
}

struct GetAllContactsUseCaseImpl {
    let contactRepository: ContactRepository

    init(contactRepository: ContactRepository) {
        self.contactRepository = contactRepository
    }
}

extension GetAllContactsUseCaseImpl: GetAllContactsUseCase {
    func execute() throws -> [Contact] {
        try contactRepository.fetchAll()
    }
}
