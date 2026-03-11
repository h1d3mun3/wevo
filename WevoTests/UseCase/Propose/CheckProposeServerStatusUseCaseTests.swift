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

    private func makeHashedPropose(proposeID: UUID, signatures: [Signature]) -> HashedPropose {
        HashedPropose(
            id: proposeID,
            payloadHash: "hash",
            signatures: signatures,
            createdAt: .now
        )
    }

    @Test func testReturnsExistsWhenProposeFoundOnServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sig = makeSignature()
        let propose = makePropose(signatures: [sig])
        mockAPI.getProposeResult = makeHashedPropose(proposeID: propose.id, signatures: [sig])

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let status = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(status.exists == true)
        #expect(mockAPI.getProposeCalledWithID == propose.id)
    }

    @Test func testDetectsNewServerSignatures() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let localSig = makeSignature(publicKey: "local-key")
        let serverOnlySig = makeSignature(publicKey: "server-key")
        let propose = makePropose(signatures: [localSig])

        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            signatures: [localSig, serverOnlySig]
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let status = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(status.newServerSignatures.count == 1)
        #expect(status.newServerSignatures[0].publicKey == "server-key")
    }

    @Test func testDetectsLocalOnlySignatures() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sharedSig = makeSignature(publicKey: "shared-key")
        let localOnlySig = makeSignature(publicKey: "local-only-key")
        let propose = makePropose(signatures: [sharedSig, localOnlySig])

        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            signatures: [sharedSig]
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let status = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(status.localOnlySignatures.count == 1)
        #expect(status.localOnlySignatures[0].publicKey == "local-only-key")
    }

    @Test func testReturnsEmptyWhenSignaturesMatch() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sig1 = makeSignature(publicKey: "key1")
        let sig2 = makeSignature(publicKey: "key2")
        let propose = makePropose(signatures: [sig1, sig2])

        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            signatures: [
                makeSignature(publicKey: "key1"),
                makeSignature(publicKey: "key2")
            ]
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let status = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(status.newServerSignatures.isEmpty)
        #expect(status.localOnlySignatures.isEmpty)
    }

    @Test func testDetectsBothNewAndLocalOnlySignatures() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let sharedSig = makeSignature(publicKey: "shared")
        let localOnlySig = makeSignature(publicKey: "local-only")
        let serverOnlySig = makeSignature(publicKey: "server-only")
        let propose = makePropose(signatures: [sharedSig, localOnlySig])

        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            signatures: [sharedSig, serverOnlySig]
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let status = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(status.newServerSignatures.count == 1)
        #expect(status.newServerSignatures[0].publicKey == "server-only")
        #expect(status.localOnlySignatures.count == 1)
        #expect(status.localOnlySignatures[0].publicKey == "local-only")
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(signatures: [makeSignature()])

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: CheckProposeServerStatusUseCaseError.invalidServerURL) {
            try await useCase.execute(propose: propose, serverURL: "")
        }
    }

    @Test func testPropagatesAPIError() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        mockAPI.getProposeError = ProposeAPIClient.APIError.httpError(statusCode: 404)
        let propose = makePropose(signatures: [makeSignature()])

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
    }
}
