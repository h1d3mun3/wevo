//
//  LoadSettingsDataUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

struct SettingsData {
    let proposes: [Propose]
    let spaces: [Space]
    let contacts: [Contact]
}

protocol LoadSettingsDataUseCase {
    func execute() throws -> SettingsData
}

struct LoadSettingsDataUseCaseImpl: LoadSettingsDataUseCase {
    let proposeRepository: ProposeRepository
    let spaceRepository: SpaceRepository
    let contactRepository: ContactRepository

    func execute() throws -> SettingsData {
        let proposes = try proposeRepository.fetchAll()
        let spaces = try spaceRepository.fetchAll()
        let contacts = try contactRepository.fetchAll()
        return SettingsData(proposes: proposes, spaces: spaces, contacts: contacts)
    }
}
