//
//  GetIdentityNicknameUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetIdentityNicknameUseCaseTests {

    let mockKeychainRepository = MockKeychainRepository()

    @Test("IDに対応するIdentityのニックネームを返す")
    func executeSuccess() {
        let id = UUID()
        let identity = Identity(id: id, nickname: "My Key", publicKey: "PK")
        mockKeychainRepository.getIdentityResult = identity

        let useCase = GetIdentityNicknameUseCaseImpl(keychainRepository: mockKeychainRepository)
        let nickname = useCase.execute(id: id)

        #expect(nickname == "My Key")
        #expect(mockKeychainRepository.getIdentityCalledWithID == id)
    }

    @Test("Identityが見つからない場合Unknownを返す")
    func executeReturnsUnknownWhenNotFound() {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let useCase = GetIdentityNicknameUseCaseImpl(keychainRepository: mockKeychainRepository)
        let nickname = useCase.execute(id: UUID())

        #expect(nickname == "Unknown")
    }
}
