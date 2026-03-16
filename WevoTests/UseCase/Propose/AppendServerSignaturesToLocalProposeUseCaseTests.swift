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

    /// Helper to generate a test Propose
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

    /// Helper to generate a test HashedPropose
    private func makeServerPropose(
        proposeID: UUID,
        counterpartyPublicKey: String = "counterpartyKey",
        signSignature: String? = "serverSig123",
        signTimestamp: String? = "2026-01-02T00:00:00Z"
    ) -> HashedPropose {
        let counterparty = ProposeCounterparty(
            publicKey: counterpartyPublicKey,
            signSignature: signSignature,
            signTimestamp: signTimestamp,
            honorSignature: nil,
            honorTimestamp: nil,
            partSignature: nil,
            partTimestamp: nil
        )
        return HashedPropose(
            id: proposeID,
            contentHash: "hash",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterparties: [counterparty],
            status: .signed,
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
        try useCase.execute(proposeID: proposeID, serverPropose: makeServerPropose(proposeID: proposeID))

        // Assert: counterpartySignSignature is set
        #expect(mockRepository.fetchByIDCalledWithID == proposeID)
        #expect(mockRepository.updateCalled == true)
        #expect(mockRepository.updatedPropose?.counterpartySignSignature == "serverSig123")
    }

    @Test func testSetsCounterpartySignTimestamp() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, serverPropose: makeServerPropose(proposeID: proposeID, signTimestamp: "2026-03-01T00:00:00Z"))

        // Assert: counterpartySignTimestamp is set
        #expect(mockRepository.updatedPropose?.counterpartySignTimestamp == "2026-03-01T00:00:00Z")
    }

    @Test func testLocalStatusBecomesSignedAfterAppend() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID, counterpartySignSignature: nil)
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, serverPropose: makeServerPropose(proposeID: proposeID))

        // Assert: status is signed after signing
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
        try useCase.execute(
            proposeID: proposeID,
            serverPropose: makeServerPropose(proposeID: proposeID, counterpartyPublicKey: "cpartyKey")
        )

        // Assert: other fields are preserved
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
            try useCase.execute(proposeID: UUID(), serverPropose: makeServerPropose(proposeID: UUID()))
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
            try useCase.execute(proposeID: proposeID, serverPropose: makeServerPropose(proposeID: proposeID))
        }
    }
}
