//
//  ApplyServerStatusToLocalProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/15/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ApplyServerStatusToLocalProposeUseCaseTests {

    private func makePropose(
        id: UUID = UUID(),
        counterpartySignSignature: String? = "signSig",
        finalStatus: ProposeStatus? = nil
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: counterpartySignSignature,
            finalStatus: finalStatus,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testAppliesHonoredStatus() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        mockRepository.fetchByIDResult = makePropose(id: proposeID)

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        try useCase.execute(proposeID: proposeID, status: .honored)

        #expect(mockRepository.updateCalled == true)
        #expect(mockRepository.updatedPropose?.finalStatus == .honored)
        #expect(mockRepository.updatedPropose?.localStatus == .honored)
    }

    @Test func testAppliesPartedStatus() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        mockRepository.fetchByIDResult = makePropose(id: proposeID)

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        try useCase.execute(proposeID: proposeID, status: .parted)

        #expect(mockRepository.updatedPropose?.finalStatus == .parted)
        #expect(mockRepository.updatedPropose?.localStatus == .parted)
    }

    @Test func testAppliesDissolvedStatus() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        mockRepository.fetchByIDResult = makePropose(id: proposeID)

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        try useCase.execute(proposeID: proposeID, status: .dissolved)

        #expect(mockRepository.updatedPropose?.finalStatus == .dissolved)
        #expect(mockRepository.updatedPropose?.localStatus == .dissolved)
    }

    @Test func testPreservesOtherProposeFields() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let propose = makePropose(id: proposeID, counterpartySignSignature: "existingSig")
        mockRepository.fetchByIDResult = propose

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        try useCase.execute(proposeID: proposeID, status: .honored)

        #expect(mockRepository.updatedPropose?.id == proposeID)
        #expect(mockRepository.updatedPropose?.message == "test")
        #expect(mockRepository.updatedPropose?.creatorPublicKey == "creatorKey")
        #expect(mockRepository.updatedPropose?.counterpartyPublicKey == "counterpartyKey")
        #expect(mockRepository.updatedPropose?.counterpartySignSignature == "existingSig")
    }

    @Test func testFetchesCorrectProposeID() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        mockRepository.fetchByIDResult = makePropose(id: proposeID)

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        try useCase.execute(proposeID: proposeID, status: .dissolved)

        #expect(mockRepository.fetchByIDCalledWithID == proposeID)
    }

    @Test func testThrowsWhenFetchFails() throws {
        let mockRepository = MockProposeRepository()
        mockRepository.fetchByIDError = NSError(domain: "Test", code: -1)

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        #expect(throws: NSError.self) {
            try useCase.execute(proposeID: UUID(), status: .honored)
        }
        #expect(mockRepository.updateCalled == false)
    }

    @Test func testThrowsWhenUpdateFails() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        mockRepository.fetchByIDResult = makePropose(id: proposeID)
        mockRepository.updateError = NSError(domain: "Test", code: -1)

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        #expect(throws: NSError.self) {
            try useCase.execute(proposeID: proposeID, status: .honored)
        }
    }
}
