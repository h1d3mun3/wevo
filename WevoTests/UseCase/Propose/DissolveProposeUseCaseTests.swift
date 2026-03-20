//
//  DissolveProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/15/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct DissolveProposeUseCaseTests {

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

    @Test func testCreatorCanDissolve() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "dissolveSig"

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        #expect(mockAPI.dissolveProposeCalled == true)
        #expect(mockAPI.dissolveProposeProposeID == proposeID)
        #expect(mockAPI.dissolveProposeinput?.publicKey == "creatorKey")
        #expect(mockAPI.dissolveProposeinput?.signature == "dissolveSig")
    }

    @Test func testCounterpartyCanDissolve() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, counterpartyPublicKey: "counterpartyKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "dissolveSig"

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        #expect(mockAPI.dissolveProposeCalled == true)
        #expect(mockAPI.dissolveProposeProposeID == proposeID)
    }

    @Test func testThirdPartyCannotDissolve() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyKey")

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Eve", publicKey: "unrelatedKey")

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: DissolveProposeUseCaseError.notParticipant) {
            try await useCase.execute(propose: propose, identityID: UUID(), serverURL: "https://example.com")
        }
        #expect(mockAPI.dissolveProposeCalled == false)
    }

    @Test func testSignatureMessageFormat() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURL: "https://example.com")

        // Verify v1 message format: "dissolved." + proposeId + contentHash + signerPublicKey + timestamp
        let signedMessage = mockKeychain.signMessageCalledWithMessage ?? ""
        #expect(signedMessage.hasPrefix("dissolved."))
        #expect(signedMessage.contains(proposeID.uuidString))
        #expect(signedMessage.contains("creatorKey"))  // signerPublicKey embedded in v1 message
    }

    @Test func testThrowsInvalidServerURL() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let propose = makePropose(creatorPublicKey: "creatorKey")
        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: DissolveProposeUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, identityID: UUID(), serverURL: "not a url")
        }
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURL: "https://example.com")
        }
    }

    @Test func testThrowsWhenAPIFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let propose = makePropose(creatorPublicKey: "creatorKey")
        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"
        mockAPI.dissolveProposeerror = NSError(domain: "API", code: 409)

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: mockKeychain, apiClient: mockAPI)

        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: propose, identityID: UUID(), serverURL: "https://example.com")
        }
    }
}
