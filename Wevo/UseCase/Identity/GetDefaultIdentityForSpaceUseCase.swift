//
//  GetDefaultIdentityForSpaceUseCase.swift
//  Wevo
//
//  Created on 3/17/26.
//

import Foundation

protocol GetDefaultIdentityForSpaceUseCase {
    /// Returns the Identity corresponding to the space's defaultIdentityID, or nil if not set
    func execute(space: Space) throws -> Identity?
}

struct GetDefaultIdentityForSpaceUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension GetDefaultIdentityForSpaceUseCaseImpl: GetDefaultIdentityForSpaceUseCase {
    func execute(space: Space) throws -> Identity? {
        guard let defaultIdentityID = space.defaultIdentityID else { return nil }
        let identities = try keychainRepository.getAllIdentities()
        return identities.first { $0.id == defaultIdentityID }
    }
}
