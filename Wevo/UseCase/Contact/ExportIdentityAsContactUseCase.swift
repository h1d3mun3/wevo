//
//  ExportIdentityAsContactUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

protocol ExportIdentityAsContactUseCase {
    func execute(identity: Identity) throws -> URL
}

struct ExportIdentityAsContactUseCaseImpl: ExportIdentityAsContactUseCase {
    func execute(identity: Identity) throws -> URL {
        try ContactTransfer.exportToFile(identity: identity)
    }
}
