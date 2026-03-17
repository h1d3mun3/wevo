//
//  LoadIdentitiesWithDefaultSelectionUseCase.swift
//  Wevo
//
//  Created on 3/17/26.
//

import Foundation

protocol LoadIdentitiesWithDefaultSelectionUseCase {
    /// Returns all identities and the ID that should be selected by default (first identity's ID, or nil if empty)
    func execute() throws -> ([Identity], UUID?)
}

struct LoadIdentitiesWithDefaultSelectionUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension LoadIdentitiesWithDefaultSelectionUseCaseImpl: LoadIdentitiesWithDefaultSelectionUseCase {
    func execute() throws -> ([Identity], UUID?) {
        let loadedIdentities = try keychainRepository.getAllIdentities()
        let defaultSelectedID = loadedIdentities.first?.id
        return (loadedIdentities, defaultSelectedID)
    }
}
