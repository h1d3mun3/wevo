//
//  AutoApplyServerChangesUseCaseTests.swift
//  WevoTests
//
//  Created on 3/17/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct AutoApplyServerChangesUseCaseTests {

    private let creatorPublicKey = "creatorKey"
    private let counterpartyPublicKey = "counterpartyKey"

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

    @Test func testAppliesPendingCounterpartySignature() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let propose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = propose
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: proposeID,
            counterpartySignSignature: "serverSig",
            status: .signed
        )

        let useCase = AutoApplyServerChangesUseCaseImpl(apiClient: mockAPI, proposeRepository: mockRepository)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        // Assert: update was called with new counterparty signature
        #expect(mockRepository.updateCalled == true)
        #expect(mockRepository.updatedPropose?.counterpartySignSignature == "serverSig")
    }

    @Test func testAppliesPendingStatusTransition() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let propose = makePropose(id: proposeID, counterpartySignSignature: "sig")
        mockRepository.fetchByIDResult = propose
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: proposeID,
            counterpartySignSignature: "sig",
            status: .honored
        )

        let useCase = AutoApplyServerChangesUseCaseImpl(apiClient: mockAPI, proposeRepository: mockRepository)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        // Assert: AppendServerSignatures was called (terminal status triggers pendingServerUpdate)
        #expect(mockRepository.updateCalled == true)
    }

    @Test func testDoesNothingWhenNoPendingChanges() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let propose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: proposeID,
            counterpartySignSignature: nil,
            status: .proposed
        )

        let useCase = AutoApplyServerChangesUseCaseImpl(apiClient: mockAPI, proposeRepository: mockRepository)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)

        // Assert: no updates triggered
        #expect(mockRepository.updateCalled == false)
    }

    @Test func testThrowsWhenAPIClientThrows() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let mockRepository = MockProposeRepository()
        let propose = makePropose()
        mockAPI.getProposeError = NSError(domain: "TestError", code: -1)

        let useCase = AutoApplyServerChangesUseCaseImpl(apiClient: mockAPI, proposeRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)
        }
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let mockRepository = MockProposeRepository()
        let propose = makePropose()

        let useCase = AutoApplyServerChangesUseCaseImpl(apiClient: mockAPI, proposeRepository: mockRepository)

        // Act & Assert
        await #expect(throws: CheckProposeServerStatusUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, serverURL: "", myPublicKey: nil)
        }
    }

    @Test func testThrowsWhenRepositoryUpdateFails() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let propose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = propose
        mockRepository.updateError = NSError(domain: "RepoError", code: -1)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: proposeID,
            counterpartySignSignature: "serverSig",
            status: .signed
        )

        let useCase = AutoApplyServerChangesUseCaseImpl(apiClient: mockAPI, proposeRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com", myPublicKey: nil)
        }
    }
}
