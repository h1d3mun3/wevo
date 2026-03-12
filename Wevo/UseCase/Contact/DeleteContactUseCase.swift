//
//  DeleteContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol DeleteContactUseCase {
    func execute(id: UUID) throws
}

struct DeleteContactUseCaseImpl {
    let contactRepository: ContactRepository

    init(contactRepository: ContactRepository) {
        self.contactRepository = contactRepository
    }
}

extension DeleteContactUseCaseImpl: DeleteContactUseCase {
    func execute(id: UUID) throws {
        try contactRepository.delete(by: id)
    }
}
