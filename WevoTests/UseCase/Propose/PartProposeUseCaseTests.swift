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

        let mockRepo = MockProposeRepository()
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

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

        let mockRepo = MockProposeRepository()
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

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

        let mockRepo = MockProposeRepository()
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: PartProposeUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["not a url"])
        }
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let mockRepo = MockProposeRepository()
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

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
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.partProposeCalled == false)
    }

    @Test func testThrowsWhenAPIFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"
        mockAPI.partProposeerror = NSError(domain: "API", code: 409)

        let mockRepo = MockProposeRepository()
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["https://example.com"])
        }
    }

    @Test func testCreatorPartSetsCreatorPartSignature() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let identityID = UUID()

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "creatorPartSig"

        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyKey")
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

        #expect(mockRepo.updatedPropose?.creatorPartSignature == "creatorPartSig")
        #expect(mockRepo.updatedPropose?.counterpartyPartSignature == nil)
    }

    @Test func testCounterpartyPartSetsCounterpartyPartSignature() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let identityID = UUID()

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Bob", publicKey: "counterpartyKey")
        mockKeychain.signMessageResult = "counterpartyPartSig"

        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyKey")
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityID: identityID, serverURLs: ["https://example.com"])

        #expect(mockRepo.updatedPropose?.counterpartyPartSignature == "counterpartyPartSig")
        #expect(mockRepo.updatedPropose?.creatorPartSignature == nil)
    }

    @Test func testThrowsWhenProposeIsNotSigned() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()

        let propose = Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: PartProposeUseCaseError.statusIsNotSigned) {
            try await useCase.execute(propose: propose, identityID: UUID(), serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.partProposeCalled == false)
    }

    @Test func testThrowsWhenUpdateFails() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let identityID = UUID()

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "sig"
        mockRepo.updateError = NSError(domain: "Test", code: -1)

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: makePropose(), identityID: identityID, serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.partProposeCalled == false)
    }
}
