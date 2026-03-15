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

    /// テスト用Proposeを生成するヘルパー
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

    /// テスト用HashedProposeを生成するヘルパー
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
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()
        mockAPI.getProposeResult = makeHashedPropose(proposeID: propose.id, status: .proposed)

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(result.serverStatus == .proposed)
        #expect(mockAPI.getProposeCalledWithID == propose.id)
    }

    @Test func testDetectsPendingCounterpartySignSignature() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        // ローカルは未署名、サーバーでは署名済み
        let propose = makePropose(counterpartySignSignature: nil)
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "serverCounterpartySig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert: pendingCounterpartySignSignatureが返ってくる
        #expect(result.pendingCounterpartySignSignature == "serverCounterpartySig")
        #expect(result.serverStatus == .signed)
    }

    @Test func testNoPendingSignatureWhenAlreadyLocallySet() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        // ローカルでも署名済み
        let propose = makePropose(counterpartySignSignature: "localSig")
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: "serverCounterpartySig",
            status: .signed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert: ローカルに既に署名があるのでpendingはnil
        #expect(result.pendingCounterpartySignSignature == nil)
    }

    @Test func testNoPendingSignatureWhenCounterpartyNotSignedOnServer() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose(counterpartySignSignature: nil)
        // サーバーでも未署名
        mockAPI.getProposeResult = makeHashedPropose(
            proposeID: propose.id,
            counterpartySignSignature: nil,
            status: .proposed
        )

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act
        let result = try await useCase.execute(propose: propose, serverURL: "https://example.com")

        // Assert
        #expect(result.pendingCounterpartySignSignature == nil)
        #expect(result.serverStatus == .proposed)
    }

    @Test func testThrowsWhenServerURLIsInvalid() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        let propose = makePropose()

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
        let propose = makePropose()

        let useCase = CheckProposeServerStatusUseCaseImpl(apiClient: mockAPI)

        // Act & Assert
        await #expect(throws: ProposeAPIClient.APIError.self) {
            try await useCase.execute(propose: propose, serverURL: "https://example.com")
        }
    }
}
