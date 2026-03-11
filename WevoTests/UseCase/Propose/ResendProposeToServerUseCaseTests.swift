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

    @Test func testSendsProposeToServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sig = makeSignature()
        let propose = makePropose(signatures: [sig])

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(mockAPI.createProposeCalled == true)
        #expect(mockAPI.createProposeInput?.id == propose.id)
        #expect(mockAPI.createProposeInput?.payloadHash == propose.payloadHash)
        #expect(mockAPI.createProposeInput?.publicKey == sig.publicKey)
    }

    @Test func testSendsAllSignatures() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sig1 = makeSignature(publicKey: "key1", signature: "sig1")
        let sig2 = makeSignature(publicKey: "key2", signature: "sig2")
        let propose = makePropose(signatures: [sig1, sig2])

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(mockAPI.createProposeInput?.signatures.count == 2)
        #expect(mockAPI.createProposeInput?.signatures[0].publicKey == "key1")
        #expect(mockAPI.createProposeInput?.signatures[1].publicKey == "key2")
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(signatures: [makeSignature()])

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
        let propose = makePropose(signatures: [])

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
        let propose = makePropose(signatures: [makeSignature()])

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
    }

    @Test func testUsesFirstSignaturePublicKeyAsProposePK() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let firstSig = makeSignature(publicKey: "creator-key")
        let secondSig = makeSignature(publicKey: "signer-key")
        let propose = makePropose(signatures: [firstSig, secondSig])

        let useCase = ResendProposeToServerUseCaseImpl(apiClient: mockAPI)

        // Act
        try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(mockAPI.createProposeInput?.publicKey == "creator-key")
    }
}
