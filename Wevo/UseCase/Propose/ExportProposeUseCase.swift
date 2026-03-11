//
//  ExportProposeUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol ExportProposeUseCase {
    func execute(propose: Propose, space: Space) throws -> URL
}

struct ExportProposeUseCaseImpl: ExportProposeUseCase {
    func execute(propose: Propose, space: Space) throws -> URL {
        return try ProposeExporter.exportPropose(propose, space: space)
    }
}
