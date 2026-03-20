//
//  PartProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/15/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct PartProposeUseCaseTests {

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
            counterpartySignSignature: "signedSig",
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testPartCallsAPIWithCorrectProposeID() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "partSig"

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        #expect(mockAPI.partProposeCalled == true)
        #expect(mockAPI.partProposeProposeID == proposeID)
        #expect(mockAPI.partProposeinput?.publicKey == "creatorKey")
        #expect(mockAPI.partProposeinput?.signature == "partSig")
    }

    @Test func testSignatureMessageFormat() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        // Verify v1 message format: "parted." + proposeId + contentHash + signerPublicKey + timestamp
        let signedMessage = mockKeychain.signMessageCalledWithMessage ?? ""
        #expect(signedMessage.hasPrefix("parted."))
        #expect(signedMessage.contains(proposeID.uuidString))
        #expect(signedMessage.contains("creatorKey"))  // signerPublicKey embedded in v1 message
    }

    @Test func testThrowsInvalidServerURL() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: PartProposeUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "not a url")
        }
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "https://example.com")
        }
    }

    @Test func testThrowsWhenSignMessageFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageError = KeychainError.biometricAuthFailed

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "https://example.com")
        }
        #expect(mockAPI.partProposeCalled == false)
    }

    @Test func testThrowsWhenAPIFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"
        mockAPI.partProposeerror = NSError(domain: "API", code: 409)

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "https://example.com")
        }
    }
}
