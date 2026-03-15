//
//  SignProposeServerOnlyUseCaseTests.swift
//  WevoTests
//
//  Created on 3/15/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct SignProposeServerOnlyUseCaseTests {

    private func makePropose(
        id: UUID = UUID(),
        creatorPublicKey: String = "creatorKey",
        counterpartyPublicKey: String = "counterpartyKey"
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testSignCallsAPIWithCorrectProposeID() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, counterpartyPublicKey: "counterpartyKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "signSig"

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        #expect(mockAPI.signProposeCalled == true)
        #expect(mockAPI.signProposeID == proposeID)
        #expect(mockAPI.signProposeInput?.signerPublicKey == "counterpartyKey")
        #expect(mockAPI.signProposeInput?.signature == "signSig")
    }

    @Test func testReturnsSignatureString() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let identityID = UUID()
        let propose = makePropose(counterpartyPublicKey: "counterpartyKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "expectedSig"

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        #expect(result == "expectedSig")
    }

    @Test func testSignatureMessageFormat() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, counterpartyPublicKey: "counterpartyKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "sig"

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        let signedMessage = mockKeychain.signMessageCalledWithMessage ?? ""
        #expect(signedMessage.hasPrefix(proposeID.uuidString))
        #expect(signedMessage.contains(propose.payloadHash))
        #expect(signedMessage.contains("counterpartyKey"))
    }

    @Test func testThrowsInvalidServerURL() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Bob", publicKey: "counterpartyKey")

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: SignProposeServerOnlyUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "not a url")
        }
    }

    @Test func testThrowsNotCounterparty() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let identityID = UUID()
        // Identity's publicKey is "creatorKey", but propose.counterpartyPublicKey is "counterpartyKey"
        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: SignProposeServerOnlyUseCaseError.notCounterparty) {
            try await useCase.execute(
                propose: makePropose(counterpartyPublicKey: "counterpartyKey"),
                identityID: identityID,
                serverURL: "https://example.com"
            )
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "https://example.com")
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenSignMessageFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let identityID = UUID()
        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageError = KeychainError.biometricAuthFailed

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(
                propose: makePropose(counterpartyPublicKey: "counterpartyKey"),
                identityID: identityID,
                serverURL: "https://example.com"
            )
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenAPIFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let identityID = UUID()
        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "sig"
        mockAPI.signProposeError = ProposeAPIClient.APIError.httpError(statusCode: 409)

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: (any Error).self) {
            try await useCase.execute(
                propose: makePropose(counterpartyPublicKey: "counterpartyKey"),
                identityID: identityID,
                serverURL: "https://example.com"
            )
        }
    }
}
