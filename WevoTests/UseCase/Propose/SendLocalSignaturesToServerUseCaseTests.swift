//
//  SendLocalSignaturesToServerUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct SendLocalSignaturesToServerUseCaseTests {

    private let counterpartyPublicKey = "counterpartyKey"

    /// Helper to generate a test Propose
    private func makePropose(
        id: UUID = UUID(),
        counterpartyPublicKey: String = "counterpartyKey",
        counterpartySignSignature: String? = "counterpartySig"
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testSendsCounterpartySignatureToServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "myCounterpartySig")

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act: when IdentityPublicKey matches CounterpartyPublicKey
        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURL: "https://example.com")

        // Assert: signPropose endpoint was called
        #expect(mockAPI.signProposeCalled == true)
        #expect(mockAPI.signProposeID == propose.id)
        #expect(mockAPI.signProposeInput?.signerPublicKey == counterpartyPublicKey)
        #expect(mockAPI.signProposeInput?.signature == "myCounterpartySig")
    }

    @Test func testSkipsWhenIdentityIsNotCounterparty() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: "mySig")

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act: does not send with Creator's PublicKey
        try await useCase.execute(propose: propose, identityPublicKey: "creatorKey", serverURL: "https://example.com")

        // Assert: signPropose is not called
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsNoSignatureFoundWhenCounterpartySignSignatureIsNil() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        // counterpartySignSignature is nil (unsigned)
        let propose = makePropose(counterpartySignSignature: nil)

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: SendLocalSignaturesToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURL: "https://example.com")
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: SendLocalSignaturesToServerUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURL: "")
        }
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsWhenAPICallFails() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        mockAPI.signProposeError = ProposeAPIClient.APIError.httpError(statusCode: 500)
        let propose = makePropose()

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURL: "https://example.com")
        }
    }
}
