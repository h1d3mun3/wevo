//
//  CheckProposeServerStatusUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct CheckProposeServerStatusUseCaseTests {

    private let creatorPublicKey = "creatorKey"
    private let counterpartyPublicKey = "counterpartyKey"

    /// Helper to generate a test Propose
    private func makePropose(
        id: UUID = UUID(),
        counterpartySignSignature: String? = nil
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    /// Helper to generate a test HashedPropose
    private func makeHashedPropose(
        proposeID: UUID,
        counterpartySignSignature: String? = nil,
        status: ProposeStatus = .proposed
    ) -> HashedPropose {
        let counterparty = ProposeCounterparty(
            publicKey: counterpartyPublicKey,
            signSignature: counterpartySignSignature,
            signTimestamp: counterpartySignSignature != nil ? "2026-01-02T00:00:00Z" : nil,
            honorSignature: nil,
            honorTimestamp: nil,
            partSignature: nil,
            partTimestamp: nil
        )
        return HashedPropose(
            id: proposeID,
            contentHash: "hash",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterparties: [counterparty],
            status: status,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testReturnsServerStatusWhenProposeFound() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()
        mockAPI.getProposeResult = makeHashedPropose(proposeID: propose.id, status: .proposed)

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.serverStatus == .proposed)
        #expect(mockAPI.getProposeCalledWithID == propose.id)
    }

    @Test func testDetectsPendingCounterpartySignSignature() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "serverCounterpartySig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate != nil)
        #expect(result.pendingServerUpdate?.counterparties.first?.signSignature == "serverCounterpartySig")
        #expect(result.serverStatus == .signed)
    }

    @Test func testNoPendingSignatureWhenAlreadyLocallySet() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "localSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "serverCounterpartySig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate == nil)
    }

    @Test func testNoPendingSignatureWhenCounterpartyNotSignedOnServer() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: nil,
            status: .proposed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate == nil)
        #expect(result.serverStatus == .proposed)
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        await #expect(throws: CheckProposeServerStatusUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, serverURLs: [], myPublicKey: nil)
        }
    }

    @Test func testThrowsProposeNotFoundOn404() async throws {
        let mockAPI = MockProposeAPIClient()
        mockAPI.getProposeError = ProposeAPIClient.APIError.httpError(statusCode: 404)
        let propose = makePropose()

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        await #expect(throws: CheckProposeServerStatusUseCaseError.proposeNotFound) {
            try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)
        }
    }

    @Test func testPropagatesNon404APIError() async throws {
        let mockAPI = MockProposeAPIClient()
        mockAPI.getProposeError = ProposeAPIClient.APIError.httpError(statusCode: 500)
        let propose = makePropose()

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)
        }
    }

    // MARK: - pendingServerUpdate for terminal status tests

    @Test func testDetectsPendingHonoredStatus() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .honored
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate != nil)
        #expect(result.pendingServerUpdate?.status == .honored)
        #expect(result.serverStatus == .honored)
    }

    @Test func testDetectsPendingPartedStatus() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .parted
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate != nil)
        #expect(result.pendingServerUpdate?.status == .parted)
    }

    @Test func testDetectsPendingDissolvedStatus() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: nil,
            status: .dissolved
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate != nil)
        #expect(result.pendingServerUpdate?.status == .dissolved)
    }

    @Test func testNoPendingStatusTransitionWhenLocalAlreadyMatches() async throws {
        let mockAPI = MockProposeAPIClient()
        // Honored locally: both honor signatures are present
        let propose = Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: "signSig",
            counterpartyHonorSignature: "counterpartyHonorSig",
            counterpartyHonorTimestamp: "2026-01-02T00:00:00Z",
            creatorHonorSignature: "creatorHonorSig",
            creatorHonorTimestamp: "2026-01-03T00:00:00Z",
            createdAt: .now,
            updatedAt: .now
        )
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .honored
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.pendingServerUpdate == nil)
    }

    @Test func testNoPendingStatusTransitionForNonTerminalStatus() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "serverSig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        // .signed is not a terminal state, so no pendingStatusTransition;
        // but counterparty signature is new, so pendingServerUpdate is set
        #expect(result.pendingServerUpdate?.status == .signed)
    }

    // MARK: - myHonorSigned / myPartSigned tests

    @Test func testDetectsMyHonorSignedAsCreator() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = HashedPropose(
            id: propose.id,
            contentHash: "hash",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterparties: [ProposeCounterparty(publicKey: counterpartyPublicKey, signSignature: "signSig", signTimestamp: "2026-01-02T00:00:00Z", honorSignature: nil, honorTimestamp: nil, partSignature: nil, partTimestamp: nil)],
            honorCreatorSignature: "honorSig",
            status: .signed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: creatorPublicKey)

        #expect(result.myHonorSigned == true)
        #expect(result.myPartSigned == false)
    }

    @Test func testDetectsMyHonorSignedAsCounterparty() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = HashedPropose(
            id: propose.id,
            contentHash: "hash",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterparties: [ProposeCounterparty(publicKey: counterpartyPublicKey, signSignature: "signSig", signTimestamp: "2026-01-02T00:00:00Z", honorSignature: "honorSig", honorTimestamp: "2026-01-03T00:00:00Z", partSignature: nil, partTimestamp: nil)],
            honorCreatorSignature: nil,
            status: .signed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: counterpartyPublicKey)

        #expect(result.myHonorSigned == true)
        #expect(result.myPartSigned == false)
    }

    @Test func testMyHonorSignedFalseWhenNotSigned() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: creatorPublicKey)

        #expect(result.myHonorSigned == false)
        #expect(result.myPartSigned == false)
    }

    @Test func testMyHonorSignedFalseWhenPublicKeyIsNil() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: nil)

        #expect(result.myHonorSigned == false)
        #expect(result.myPartSigned == false)
    }

    @Test func testMyHonorSignedFalseWhenPublicKeyIsUnrelated() async throws {
        // Arrange: server has honor/part sigs for both creator and counterparty,
        // but the querying key belongs to neither.
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = HashedPropose(
            id: propose.id,
            contentHash: "hash",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterparties: [ProposeCounterparty(
                publicKey: counterpartyPublicKey,
                signSignature: "signSig",
                signTimestamp: "2026-01-02T00:00:00Z",
                honorSignature: "honorSig",
                honorTimestamp: "2026-03-01T00:00:00Z",
                partSignature: "partSig",
                partTimestamp: "2026-03-02T00:00:00Z"
            )],
            honorCreatorSignature: "honorCreatorSig",
            status: .honored,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act: query with a key that is neither creator nor counterparty
        let result = try await useCase.execute(propose: propose, serverURLs: ["https://example.com"], myPublicKey: "unrelatedKey")

        // Assert: unrelated key reports unsigned
        #expect(result.myHonorSigned == false)
        #expect(result.myPartSigned == false)
    }
}
