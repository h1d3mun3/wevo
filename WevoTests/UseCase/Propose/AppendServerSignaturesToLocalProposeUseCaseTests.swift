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

    @Test func testAppendsServerSignaturesToExistingPropose() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingSignature1 = Signature(id: UUID(), publicKey: "key1", signature: "sig1", createdAt: .now)
        let existingSignature2 = Signature(id: UUID(), publicKey: "key2", signature: "sig2", createdAt: .now)
        let serverSignature1 = Signature(id: UUID(), publicKey: "key3", signature: "sig3", createdAt: .now)
        let serverSignature2 = Signature(id: UUID(), publicKey: "key4", signature: "sig4", createdAt: .now)
        let serverSignature3 = Signature(id: UUID(), publicKey: "key5", signature: "sig5", createdAt: .now)

        let existingPropose = Propose(
            id: proposeID,
            message: "test",
            signatures: [existingSignature1, existingSignature2],
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try await useCase.execute(proposeID: proposeID, with: [serverSignature1, serverSignature2, serverSignature3])

        // Assert
        #expect(mockRepository.fetchByIDCalledWithID == proposeID)
        #expect(mockRepository.updateCalled == true)
        let updatedPropose = mockRepository.updatedPropose
        #expect(updatedPropose?.signatures.count == 5)
        #expect(updatedPropose?.signatures[0].publicKey == "key1")
        #expect(updatedPropose?.signatures[4].publicKey == "key5")
    }

    @Test func testWithEmptyServerSignatures() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingSignature = Signature(id: UUID(), publicKey: "key1", signature: "sig1", createdAt: .now)
        let existingPropose = Propose(
            id: proposeID,
            message: "test",
            signatures: [existingSignature],
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try await useCase.execute(proposeID: proposeID, with: [])

        // Assert
        #expect(mockRepository.updateCalled == true)
        let updatedPropose = mockRepository.updatedPropose
        #expect(updatedPropose?.signatures.count == 1)
    }

    @Test func testThrowsWhenFetchFails() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchByIDError = NSError(domain: "Test", code: -1)
        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(proposeID: UUID(), with: [])
        }
    }

    @Test func testThrowsWhenUpdateFails() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = Propose(
            id: proposeID,
            message: "test",
            signatures: [],
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose
        mockRepository.updateError = NSError(domain: "Test", code: -1)

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(proposeID: proposeID, with: [])
        }
    }
}
