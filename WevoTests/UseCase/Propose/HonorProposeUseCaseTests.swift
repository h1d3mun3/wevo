//
//  HonorProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/15/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct HonorProposeUseCaseTests {

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

    @Test func testHonorCallsAPIWithCorrectProposeID() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "honorSig"

        let mockRepo = MockProposeRepository()
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

        #expect(mockAPI.honorProposeCalled == true)
        #expect(mockAPI.honorProposeProposeID == proposeID)
        #expect(mockAPI.honorProposeinput?.publicKey == "creatorKey")
        #expect(mockAPI.honorProposeinput?.signature == "honorSig")
    }

    @Test func testSignatureMessageFormat() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        let proposeID = UUID()
        let identityID = UUID()
        let propose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"

        let mockRepo = MockProposeRepository()
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

        let signedMessage = mockKeychain.signMessageCalledWithMessage ?? ""
        #expect(signedMessage.hasPrefix("honored."))
        #expect(signedMessage.contains(proposeID.uuidString))
        #expect(signedMessage.contains("creatorKey"))  // signerPublicKey embedded in v1 message
    }

    @Test func testThrowsInvalidServerURL() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")

        let mockRepo = MockProposeRepository()
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: HonorProposeUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["not a url"])
        }
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let mockRepo = MockProposeRepository()
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["https://example.com"])
        }
    }

    @Test func testThrowsWhenSignMessageFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageError = KeychainError.biometricAuthFailed

        let mockRepo = MockProposeRepository()
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.honorProposeCalled == false)
    }

    @Test func testThrowsWhenAPIFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"
        mockAPI.honorProposeerror = NSError(domain: "API", code: 409)

        let mockRepo = MockProposeRepository()
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["https://example.com"])
        }
    }

    @Test func testCreatorHonorSetsCreatorHonorSignature() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let identityID = UUID()

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "creatorHonorSig"

        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyKey")
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

        #expect(mockRepo.updatedPropose?.creatorHonorSignature == "creatorHonorSig")
        #expect(mockRepo.updatedPropose?.counterpartyHonorSignature == nil)
    }

    @Test func testCounterpartyHonorSetsCounterpartyHonorSignature() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let identityID = UUID()

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "counterpartyHonorSig"

        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyKey")
        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

        #expect(mockRepo.updatedPropose?.counterpartyHonorSignature == "counterpartyHonorSig")
        #expect(mockRepo.updatedPropose?.creatorHonorSignature == nil)
    }

    @Test func testThrowsWhenUpdateFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let identityID = UUID()

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"
        mockRepo.updateError = NSError(domain: "Test", code: -1)

        let useCase = HonorProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: makePropose(), identityID: identityID, serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.honorProposeCalled == false)
    }
}
