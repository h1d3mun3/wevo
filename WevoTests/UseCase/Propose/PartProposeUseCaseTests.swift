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

    @Test func testLocalOnlyModeWhenServerURLsInvalid() async throws {
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()

        mockKeychain.getIdentityResult = Identity(id: UUID(), nickname: "Alice", publicKey: "creatorKey")

        let mockRepo = MockProposeRepository()
        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)

        try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["not a url"])

        #expect(mockRepo.updateCalled == true)
        #expect(mockAPI.partProposeCalled == false)
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

    @Test func testPartPreservesHonorSignatureFromFresherRepositoryCopy() async throws {
        // Regression: a Part must not wipe an honor signature the DB already holds when the
        // in-memory copy the UI passes in is stale (the originally-reported data-loss bug).
        let mockKeychain = MockKeychainRepository()
        let mockAPI = MockProposeAPIClient()
        let mockRepo = MockProposeRepository()
        let proposeID = UUID()
        let identityID = UUID()

        // Stale in-memory copy (no honor signature).
        let stalePropose = makePropose(id: proposeID, creatorPublicKey: "creatorKey")
        // Fresher persisted copy carrying an honor signature recorded after the row was seeded.
        let freshPropose = Propose(
            id: proposeID,
            spaceID: stalePropose.spaceID,
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: "signedSig",
            creatorHonorSignature: "creatorHonorSig",
            creatorHonorTimestamp: "2026-01-01T00:00:00Z",
            createdAt: stalePropose.createdAt,
            updatedAt: .now
        )
        mockRepo.fetchByIDResult = freshPropose

        mockKeychain.getIdentityResult = Identity(id: identityID, nickname: "Alice", publicKey: "creatorKey")
        mockKeychain.signMessageResult = "creatorPartSig"

        let useCase = PartProposeUseCaseImpl(keychainRepository: mockKeychain, proposeRepository: mockRepo, apiClient: mockAPI)
        try await useCase.execute(propose: stalePropose, identityID: identityID, serverURLs: [])

        #expect(mockRepo.fetchByIDCalledWithID == proposeID)
        #expect(mockRepo.updatedPropose?.creatorHonorSignature == "creatorHonorSig")  // preserved, not wiped
        #expect(mockRepo.updatedPropose?.creatorPartSignature == "creatorPartSig")
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
