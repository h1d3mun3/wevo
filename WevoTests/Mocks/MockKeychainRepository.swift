//
//  MockKeychainRepository.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Foundation
import LocalAuthentication
@testable import Wevo

class MockKeychainRepository: KeychainRepository {
    // MARK: - createIdentity
    var createIdentityCalled = false
    var createIdentityCallCount = 0
    var createIdentityError: Error?
    var createdIdentityID: UUID?
    var createdNickname: String?
    var createdPrivateKey: Data?

    // MARK: - getAllIdentities
    var getAllIdentitiesResult: [Identity] = []
    var getAllIdentitiesError: Error?

    // MARK: - getIdentity
    var getIdentityResult: Identity?
    var getIdentityError: Error?
    var getIdentityCalledWithID: UUID?

    // MARK: - getPrivateKey
    var getPrivateKeyResult: Data?
    var getPrivateKeyError: Error?

    // MARK: - updateNickname
    var updateNicknameCalled = false
    var updateNicknameError: Error?
    var updatedNicknameID: UUID?
    var updatedNicknameValue: String?

    // MARK: - deleteIdentityKey
    var deleteIdentityKeyCalled = false
    var deleteIdentityKeyError: Error?
    var deletedIdentityID: UUID?

    // MARK: - deleteAllIdentityKeys
    var deleteAllIdentityKeysCalled = false
    var deleteAllIdentityKeysError: Error?

    // MARK: - migrateKey
    var migrateKeyCalled = false
    var migrateKeyError: Error?
    var migrateKeyCalledWithID: UUID?

    // MARK: - signMessage
    var signMessageResult: String = ""
    var signMessageError: Error?
    var signMessageCalledWithMessage: String?
    var signMessageCalledWithIdentityID: UUID?

    // MARK: - verifySignature
    var verifySignatureResult: Bool = true
    var verifySignatureError: Error?

    // MARK: - Protocol Implementation

    func createIdentity(id: UUID, nickname: String, privateKey: Data) throws {
        createIdentityCalled = true
        createIdentityCallCount += 1
        createdIdentityID = id
        createdNickname = nickname
        createdPrivateKey = privateKey

        if let error = createIdentityError {
            throw error
        }
    }

    func getAllIdentities() throws -> [Identity] {
        if let error = getAllIdentitiesError {
            throw error
        }
        return getAllIdentitiesResult
    }

    func getIdentity(id: UUID) throws -> Identity {
        getIdentityCalledWithID = id
        if let error = getIdentityError {
            throw error
        }
        guard let result = getIdentityResult else {
            throw KeychainError.itemNotFound
        }
        return result
    }

    func getPrivateKey(id: UUID, context: LAContext? = nil) throws -> Data {
        if let error = getPrivateKeyError {
            throw error
        }
        guard let result = getPrivateKeyResult else {
            throw KeychainError.itemNotFound
        }
        return result
    }

    func updateNickname(id: UUID, newNickname: String) throws {
        updateNicknameCalled = true
        updatedNicknameID = id
        updatedNicknameValue = newNickname

        if let error = updateNicknameError {
            throw error
        }
    }

    func deleteIdentityKey(id: UUID) throws {
        deleteIdentityKeyCalled = true
        deletedIdentityID = id

        if let error = deleteIdentityKeyError {
            throw error
        }
    }

    func deleteAllIdentityKeys() throws {
        deleteAllIdentityKeysCalled = true

        if let error = deleteAllIdentityKeysError {
            throw error
        }
    }

    func migrateKey(id: UUID) throws {
        migrateKeyCalled = true
        migrateKeyCalledWithID = id

        if let error = migrateKeyError {
            throw error
        }
    }

    func signMessage(_ message: String, withIdentityId identityId: UUID, context: LAContext? = nil) throws -> String {
        signMessageCalledWithMessage = message
        signMessageCalledWithIdentityID = identityId

        if let error = signMessageError {
            throw error
        }
        return signMessageResult
    }

    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool {
        if let error = verifySignatureError {
            throw error
        }
        return verifySignatureResult
    }
}
