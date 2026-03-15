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

    /// テスト用Proposeを生成するヘルパー
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

        // Act: IdentityPublicKeyがCounterpartyPublicKeyと一致する場合
        try await useCase.execute(propose: propose, identityPublicKey: counterpartyPublicKey, serverURL: "https://example.com")

        // Assert: signProposeエンドポイントが呼ばれた
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

        // Act: CreatorのPublicKeyでは送信しない
        try await useCase.execute(propose: propose, identityPublicKey: "creatorKey", serverURL: "https://example.com")

        // Assert: signProposeは呼ばれない
        #expect(mockAPI.signProposeCalled == false)
    }

    @Test func testThrowsNoSignatureFoundWhenCounterpartySignSignatureIsNil() async throws {
        // Arrange
        let mockAPI = MockProposeAPIClient()
        // counterpartySignSignatureがnil（未署名）
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
