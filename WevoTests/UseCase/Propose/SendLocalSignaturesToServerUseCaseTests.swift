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

    private func makePropose(signatures: [Signature] = []) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            signatures: signatures,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeSignature(publicKey: String = "pubkey1", signature: String = "sig1") -> Signature {
        Signature(id: UUID(), publicKey: publicKey, signature: signature, createdAt: .now)
    }

    @Test func testSendsAllSignaturesToServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sig1 = makeSignature(publicKey: "key1", signature: "sig1")
        let sig2 = makeSignature(publicKey: "key2", signature: "sig2")
        let propose = makePropose(signatures: [sig1, sig2])

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(mockAPI.updateProposeCalled == true)
        #expect(mockAPI.updateProposeID == propose.id)
        #expect(mockAPI.updateProposeInput?.signatures.count == 2)
        #expect(mockAPI.updateProposeInput?.signatures[0].publicKey == "key1")
        #expect(mockAPI.updateProposeInput?.signatures[1].publicKey == "key2")
    }

    @Test func testUsesUpdateProposeEndpoint() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(signatures: [makeSignature()])

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(mockAPI.updateProposeCalled == true)
        #expect(mockAPI.createProposeCalled == false)
    }

    @Test func testSendsCorrectProposeInput() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let creatorSig = makeSignature(publicKey: "creator-key", signature: "creator-sig")
        let propose = makePropose(signatures: [creatorSig])

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(mockAPI.updateProposeInput?.id == propose.id)
        #expect(mockAPI.updateProposeInput?.payloadHash == propose.payloadHash)
        #expect(mockAPI.updateProposeInput?.publicKey == "creator-key")
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(signatures: [makeSignature()])

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: SendLocalSignaturesToServerUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, serverURL: "")
        }
        #expect(mockAPI.updateProposeCalled == false)
    }

    @Test func testThrowsWhenNoSignatureFound() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(signatures: [])

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: SendLocalSignaturesToServerUseCaseError.noSignatureFound) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
        #expect(mockAPI.updateProposeCalled == false)
    }

    @Test func testThrowsWhenAPICallFails() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        mockAPI.updateProposeError = ProposeAPIClient.APIError.httpError(statusCode: 500)
        let propose = makePropose(signatures: [makeSignature()])

        let useCase = SendLocalSignaturesToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
    }
}
