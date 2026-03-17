//
//  GetContactNicknamesMapUseCase.swift
//  Wevo
//
//  Created on 3/17/26.
//

import Foundation

protocol GetContactNicknamesMapUseCase {
    /// Returns a dictionary mapping publicKey → nickname for all contacts
    func execute() throws -> [String: String]
}

struct GetContactNicknamesMapUseCaseImpl {
    let contactRepository: ContactRepository

    init(contactRepository: ContactRepository) {
        self.contactRepository = contactRepository
    }
}

extension GetContactNicknamesMapUseCaseImpl: GetContactNicknamesMapUseCase {
    func execute() throws -> [String: String] {
        let contacts = try contactRepository.fetchAll()
        return Dictionary(uniqueKeysWithValues: contacts.map { ($0.publicKey, $0.nickname) })
    }
}
