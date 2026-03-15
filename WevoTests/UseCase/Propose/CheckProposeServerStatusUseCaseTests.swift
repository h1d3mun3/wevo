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
            honorSignature: nil,
            partSignature: nil
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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingCounterpartySignSignature == "serverCounterpartySig")
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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingCounterpartySignSignature == nil)
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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingCounterpartySignSignature == nil)
        #expect(result.serverStatus == .proposed)
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        await #expect(throws: CheckProposeServerStatusUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, serverURL: "", myPublicKey: nil)
        }
    }

    @Test func testPropagatesAPIError() async throws {
        let mockAPI = MockProposeAPIClient()
        mockAPI.getProposeError = ProposeAPIClient.APIError.httpError(statusCode: 404)
        let propose = makePropose()

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)
        }
    }

    // MARK: - pendingStatusTransition tests

    @Test func testDetectsPendingHonoredStatus() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "signSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .honored
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingStatusTransition == .honored)
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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingStatusTransition == .parted)
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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingStatusTransition == .dissolved)
    }

    @Test func testNoPendingStatusTransitionWhenLocalAlreadyMatches() async throws {
        let mockAPI = MockProposeAPIClient()
        let propose = Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: "signSig",
            finalStatus: .honored,
            createdAt: .now,
            updatedAt: .now
        )
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "signSig",
            status: .honored
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingStatusTransition == nil)
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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.pendingStatusTransition == nil)
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
            counterparties: [ProposeCounterparty(publicKey: counterpartyPublicKey, signSignature: "signSig", honorSignature: nil, partSignature: nil)],
            honorCreatorSignature: "honorSig",
            status: .signed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: creatorPublicKey)

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
            counterparties: [ProposeCounterparty(publicKey: counterpartyPublicKey, signSignature: "signSig", honorSignature: "honorSig", partSignature: nil)],
            honorCreatorSignature: nil,
            status: .signed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: counterpartyPublicKey)

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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: creatorPublicKey)

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

        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        #expect(result.myHonorSigned == false)
        #expect(result.myPartSigned == false)
    }
}
