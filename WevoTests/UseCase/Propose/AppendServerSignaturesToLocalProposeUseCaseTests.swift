//
//  AppendServerSignaturesToLocalProposeUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct AppendServerSignaturesToLocalProposeUseCaseTests {

    /// テスト用Proposeを生成するヘルパー
    private func makePropose(
        id: UUID = UUID(),
        counterpartyPublicKey: String = "counterpartyKey",
        counterpartySignSignature: String? = nil
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testSetsCounterpartySignSignature() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, counterpartySignSignature: "serverSig123")

        // Assert: counterpartySignSignatureがセットされた
        #expect(mockRepository.fetchByIDCalledWithID == proposeID)
        #expect(mockRepository.updateCalled == true)
        #expect(mockRepository.updatedPropose?.counterpartySignSignature == "serverSig123")
    }

    @Test func testLocalStatusBecomesSignedAfterAppend() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, counterpartySignSignature: "serverSig123")

        // Assert: 署名後はsigned状態
        #expect(mockRepository.updatedPropose?.localStatus == .signed)
    }

    @Test func testPreservesOtherProposeFields() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID, counterpartyPublicKey: "cpartyKey", counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, counterpartySignSignature: "newSig")

        // Assert: 他のフィールドが保持されている
        #expect(mockRepository.updatedPropose?.id == proposeID)
        #expect(mockRepository.updatedPropose?.counterpartyPublicKey == "cpartyKey")
        #expect(mockRepository.updatedPropose?.message == "test")
    }

    @Test func testThrowsWhenFetchFails() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchByIDError = NSError(domain: "Test", code: -1)
        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(proposeID: UUID(), counterpartySignSignature: "sig")
        }
    }

    @Test func testThrowsWhenUpdateFails() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID)
        mockRepository.fetchByIDResult = existingPropose
        mockRepository.updateError = NSError(domain: "Test", code: -1)

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(proposeID: proposeID, counterpartySignSignature: "sig")
        }
    }
}
