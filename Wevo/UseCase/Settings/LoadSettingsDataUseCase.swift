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
    let signatures: [Signature]
}

protocol LoadSettingsDataUseCase {
    func execute() throws -> SettingsData
}

struct LoadSettingsDataUseCaseImpl: LoadSettingsDataUseCase {
    let proposeRepository: ProposeRepository
    let spaceRepository: SpaceRepository
    let signatureRepository: SignatureRepository

    func execute() throws -> SettingsData {
        let proposes = try proposeRepository.fetchAll()
        let spaces = try spaceRepository.fetchAll()
        let signatures = try signatureRepository.fetchAll()
        return SettingsData(proposes: proposes, spaces: spaces, signatures: signatures)
    }
}
