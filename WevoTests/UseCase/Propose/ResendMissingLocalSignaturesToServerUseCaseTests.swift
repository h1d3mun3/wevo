//
//  ResendMissingLocalSignaturesToServerUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ResendMissingLocalSignaturesToServerUseCaseTests {

    private let counterpartyPublicKey = "counterpartyKey"

    /// Helper to generate a test Propose
    private func makePropose(
        id: UUID = UUID(),
        counterpartyPublicKey: String = "counterpartyKey",
        counterpartySignSignature: String? = "counterpartySig",
        counterpartySignTimestamp: String? = "2026-01-02T00:00:00Z"
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            counterpartySignTimestamp: counterpartySignTimestamp,
            createdAt: .now,
            updatedAt: .now
        )
    }

    /// Helper to generate a HashedPropose representing current server state (all signatures nil by default)
    private func makeServerPropose(
        id: UUID,
        counterpartyPublicKey: String = "counterpartyKey",
        counterpartySignSignature: String? = nil,
        counterpartyHonorSignature: String? = nil,
        counterpartyPartSignature: String? = nil,
        counterpartyDissolveSignature: String? = nil,
        honorCreatorSignature: String? = nil,
        partCreatorSignature: String? = nil,
        creatorDissolveSignature: String? = nil
    ) -> HashedPropose {
        HashedPropose(
            id: id,
            contentHash: "dummyHash",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterparties: [
                ProposeCounterparty(
                    publicKey: counterpartyPublicKey,
                    signSignature: counterpartySignSignature,
                    honorSignature: counterpartyHonorSignature,
                    partSignature: counterpartyPartSignature,
                    dissolveSignature: counterpartyDissolveSignature
                )
            ],
            honorCreatorSignature: honorCreatorSignature,
            partCreatorSignature: partCreatorSignature,
            creatorDissolveSignature: creatorDissolveSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testSendsCounterpartySignatureToServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "myCounterpartySig")
        // Server does not have the sign signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act: when IdentityPublicKey matches CounterpartyPublicKey
        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])

        // Assert: signPropose endpoint was called
        #expect(mockAPI.signProposeCalled == true)
        #expect(mockAPI.signProposeID == propose.id)
        #expect(mockAPI.signProposeInput?.signerPublicKey == counterpartyPublicKey)
        #expect(mockAPI.signProposeInput?.signature == "myCounterpartySig")
    }

    @Test func testSkipsWhenIdentityIsNotParticipant() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "mySig")
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act: third-party key (neither creator nor counterparty) is silently skipped
        try await useCase.execute(propose: propose, identityPublicKey: "thirdPartyKey", serverURLs: ["https://example.com"])

        // Assert: no API call made
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsNoSignatureFoundWhenCreatorHasNoSignatures() async throws {
        // Arrange: creator identity but no honor/part/dissolve signatures
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert: creator with no pending signatures → noSignatureFound
        await #expect(throws: ResendMissingLocalSignaturesToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, identityPublicKey: "creatorKey", serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsNoSignatureFoundWhenCounterpartySignSignatureIsNil() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        // counterpartySignSignature is nil (unsigned)
        let propose = makePropose(counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ResendMissingLocalSignaturesToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert: URL check fires before getPropose, so getProposeResult is not needed
        await #expect(throws: ResendMissingLocalSignaturesToServerUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: [])
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenAPICallFails() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        mockAPI.signProposeError = ProposeAPIClient.APIError.httpError(statusCode: 500)
        let propose = makePropose()
        // Server does not have the sign signature, so signPropose will be called (and fail)
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])
        }
    }

    @Test func testThrowsNoSignatureFoundWhenCounterpartySignTimestampIsNil() async throws {
        // Arrange: signature exists but timestamp is nil
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "counterpartySig", counterpartySignTimestamp: nil)
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ResendMissingLocalSignaturesToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    // MARK: - Creator signature paths

    private func makeProposeWithCreatorHonor() -> Propose {
        Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            creatorHonorSignature: "creatorHonorSig",
            creatorHonorTimestamp: "2026-01-01T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
    }

    @Test func testSendsCreatorHonorSignatureToServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makeProposeWithCreatorHonor()
        // Server does not have the creator honor signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)
        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: "creatorKey", serverURLs: ["https://example.com"])

        #expect(mockAPI.honorProposeCalled == true)
        #expect(mockAPI.honorProposeinput?.signature == "creatorHonorSig")
    }

    @Test func testSendsCreatorPartSignatureToServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            creatorPartSignature: "creatorPartSig",
            creatorPartTimestamp: "2026-01-01T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
        // Server does not have the creator part signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)
        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: "creatorKey", serverURLs: ["https://example.com"])

        #expect(mockAPI.partProposeCalled == true)
        #expect(mockAPI.partProposeinput?.signature == "creatorPartSig")
    }

    @Test func testSendsCreatorDissolveSignatureToServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            creatorDissolveSignature: "creatorDissolveSig",
            creatorDissolveTimestamp: "2026-01-01T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
        // Server does not have the creator dissolve signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)
        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: "creatorKey", serverURLs: ["https://example.com"])

        #expect(mockAPI.dissolveProposeCalled == true)
        #expect(mockAPI.dissolveProposeinput?.signature == "creatorDissolveSig")
    }

    // MARK: - Counterparty remaining signature paths

    @Test func testSendsCounterpartyHonorSignatureToServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartyHonorSignature: "cpHonorSig",
            counterpartyHonorTimestamp: "2026-01-01T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
        // Server does not have the counterparty honor signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)
        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])

        #expect(mockAPI.honorProposeCalled == true)
        #expect(mockAPI.honorProposeinput?.signature == "cpHonorSig")
    }

    @Test func testSendsCounterpartyPartSignatureToServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartyPartSignature: "cpPartSig",
            counterpartyPartTimestamp: "2026-01-01T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
        // Server does not have the counterparty part signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)
        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])

        #expect(mockAPI.partProposeCalled == true)
        #expect(mockAPI.partProposeinput?.signature == "cpPartSig")
    }

    @Test func testSendsCounterpartyDissolveSignatureToServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartyDissolveSignature: "cpDissolveSig",
            counterpartyDissolveTimestamp: "2026-01-01T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
        // Server does not have the counterparty dissolve signature yet
        mockAPI.getProposeResult = makeServerPropose(id: propose.id)
        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])

        #expect(mockAPI.dissolveProposeCalled == true)
        #expect(mockAPI.dissolveProposeinput?.signature == "cpDissolveSig")
    }

    // MARK: - Already-on-server skipping

    @Test func testSkipsSignatureAlreadyOnServer() async throws {
        // Arrange: counterparty sign is local AND already on server
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "myCounterpartySig")
        // Server already has the sign signature
        mockAPI.getProposeResult = makeServerPropose(id: propose.id, counterpartySignSignature: "myCounterpartySig")

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert: nothing to send → noSignatureFound
        await #expect(throws: ResendMissingLocalSignaturesToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testSendsOnlyMissingSignatureWhenSignIsAlreadyOnServer() async throws {
        // Arrange: counterparty has both sign (on server) and honor (missing from server)
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(), spaceID: UUID(), message: "test",
            creatorPublicKey: "creatorKey", creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: "cpSignSig",
            counterpartySignTimestamp: "2026-01-01T00:00:00Z",
            counterpartyHonorSignature: "cpHonorSig",
            counterpartyHonorTimestamp: "2026-01-02T00:00:00Z",
            createdAt: .now, updatedAt: .now
        )
        // Server has sign but not honor
        mockAPI.getProposeResult = makeServerPropose(id: propose.id, counterpartySignSignature: "cpSignSig")

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURLs: ["https://example.com"])

        // Only honor should be sent; sign was already on server
        #expect(mockAPI.signProposeCalled == false)
        #expect(mockAPI.honorProposeCalled == true)
        #expect(mockAPI.honorProposeinput?.signature == "cpHonorSig")
    }
}
