//
//  DeleteSignatureUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol DeleteSignatureUseCase {
    func execute(id: UUID) throws
}

struct DeleteSignatureUseCaseImpl {
    let signatureRepository: SignatureRepository

    init(signatureRepository: SignatureRepository) {
        self.signatureRepository = signatureRepository
    }
}

extension DeleteSignatureUseCaseImpl: DeleteSignatureUseCase {
    func execute(id: UUID) throws {
        try signatureRepository.delete(by: id)
        print("✅ Signature deleted: \(id)")
    }
}
