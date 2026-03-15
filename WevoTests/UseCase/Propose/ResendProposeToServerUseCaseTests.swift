//
//  ResendProposeToServerUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ResendProposeToServerUseCaseTests {

    /// Helper to generate a test Propose
    private func makePropose(
        id: UUID = UUID(),
        creatorPublicKey: String = "creatorKey",
        creatorSignature: String = "creatorSig",
        counterpartyPublicKey: String = "counterpartyKey"
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: creatorSignature,
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testSendsProposeToServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert: createPropose was called
        #expect(mockAPI.createProposeCalled == true)
        #expect(mockAPI.createProposeInput?.proposeId == propose.id.uuidString)
        #expect(mockAPI.createProposeInput?.contentHash == propose.payloadHash)
    }

    @Test func testSendsCreatorPublicKey() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(creatorPublicKey: "my-creator-key")

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert: Creator's public key is sent correctly
        #expect(mockAPI.createProposeInput?.creatorPublicKey == "my-creator-key")
    }

    @Test func testSendsCounterpartyPublicKey() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartyPublicKey: "my-counterparty-key")

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert: CounterpartyPublicKeys are sent correctly
        #expect(mockAPI.createProposeInput?.counterpartyPublicKeys == ["my-counterparty-key"])
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ResendProposeToServerUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, serverURL: "")
        }
        #expect(mockAPI.createProposeCalled == false)
    }

    @Test func testThrowsWhenNoSignatureFound() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        // When creatorSignature is empty
        let propose = makePropose(creatorSignature: "")

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ResendProposeToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
        #expect(mockAPI.createProposeCalled == false)
    }

    @Test func testThrowsWhenAPICallFails() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        mockAPI.createProposeError = ProposeAPIClient.APIError.httpError(statusCode: 500)
        let propose = makePropose()

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
    }
}
