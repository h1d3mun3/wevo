//
//  ImportProposeUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ImportProposeUseCaseTests {

    // MARK: - Helpers

    private func makePropose(
        id: UUID = UUID(),
        spaceID: UUID = UUID(),
        message: String = "Test message",
        creatorPublicKey: String = "creatorPubKey",
        creatorSignature: String = "creatorSig",
        counterpartyPublicKey: String = "counterpartyPubKey",
        counterpartySignSignature: String? = nil,
        counterpartySignTimestamp: String? = nil,
        counterpartyHonorSignature: String? = nil,
        counterpartyHonorTimestamp: String? = nil,
        counterpartyPartSignature: String? = nil,
        counterpartyPartTimestamp: String? = nil,
        creatorHonorSignature: String? = nil,
        creatorHonorTimestamp: String? = nil,
        creatorPartSignature: String? = nil,
        creatorPartTimestamp: String? = nil,
        dissolvedAt: String? = nil,
        finalStatus: ProposeStatus? = nil,
        signatureVersion: Int = 1
    ) -> Propose {
        Propose(
            id: id,
            spaceID: spaceID,
            message: message,
            creatorPublicKey: creatorPublicKey,
            creatorSignature: creatorSignature,
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            counterpartySignTimestamp: counterpartySignTimestamp,
            counterpartyHonorSignature: counterpartyHonorSignature,
            counterpartyHonorTimestamp: counterpartyHonorTimestamp,
            counterpartyPartSignature: counterpartyPartSignature,
            counterpartyPartTimestamp: counterpartyPartTimestamp,
            creatorHonorSignature: creatorHonorSignature,
            creatorHonorTimestamp: creatorHonorTimestamp,
            creatorPartSignature: creatorPartSignature,
            creatorPartTimestamp: creatorPartTimestamp,
            dissolvedAt: dissolvedAt,
            finalStatus: finalStatus,
            signatureVersion: signatureVersion,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeUseCase(
        proposeRepository: MockProposeRepository? = nil,
        keychainRepository: MockKeychainRepository? = nil
    ) -> ImportProposeUseCaseImpl {
        ImportProposeUseCaseImpl(
            proposeRepository: proposeRepository ?? MockProposeRepository(),
            keychainRepository: keychainRepository ?? MockKeychainRepository()
        )
    }

    // MARK: - New propose (create path)

    @Test func testNewProposeCallsCreate() throws {
        let mock = MockProposeRepository()
        let useCase = makeUseCase(proposeRepository: mock)
        let incoming = makePropose()
        let spaceID = UUID()

        try useCase.execute(propose: incoming, spaceID: spaceID)

        #expect(mock.createCalled == true)
        #expect(mock.updateCalled == false)
    }

    @Test func testNewProposeUsesGivenSpaceID() throws {
        let mock = MockProposeRepository()
        let useCase = makeUseCase(proposeRepository: mock)
        let incoming = makePropose()
        let spaceID = UUID()

        try useCase.execute(propose: incoming, spaceID: spaceID)

        #expect(mock.createdSpaceID == spaceID)
    }

    @Test func testCreateErrorThrowsFailedToSave() throws {
        let mock = MockProposeRepository()
        mock.createError = NSError(domain: "test", code: 1)
        let useCase = makeUseCase(proposeRepository: mock)

        #expect(throws: ImportProposeUseCaseError.failedToSave) {
            try useCase.execute(propose: makePropose(), spaceID: UUID())
        }
    }

    // MARK: - Existing propose (update/merge path)

    @Test func testExistingProposeCallsUpdate() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID)
        let useCase = makeUseCase(proposeRepository: mock)

        try useCase.execute(propose: makePropose(id: proposeID), spaceID: UUID())

        #expect(mock.updateCalled == true)
        #expect(mock.createCalled == false)
    }

    @Test func testExistingProposePreservesLocalSpaceID() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        let localSpaceID = UUID()
        let incomingSpaceID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, spaceID: localSpaceID)
        let useCase = makeUseCase(proposeRepository: mock)

        try useCase.execute(propose: makePropose(id: proposeID, spaceID: incomingSpaceID), spaceID: incomingSpaceID)

        #expect(mock.updatedPropose?.spaceID == localSpaceID)
    }

    @Test func testExistingProposePreservesLocalMessage() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, message: "Original message")
        let useCase = makeUseCase(proposeRepository: mock)

        try useCase.execute(propose: makePropose(id: proposeID, message: "Tampered message"), spaceID: UUID())

        #expect(mock.updatedPropose?.message == "Original message")
    }

    @Test func testIncomingCounterpartySignatureIsMerged() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, counterpartySignSignature: nil)
        let useCase = makeUseCase(proposeRepository: mock)
        let incoming = makePropose(id: proposeID, counterpartySignSignature: "newSig", counterpartySignTimestamp: "2026-01-01T00:00:00Z")

        try useCase.execute(propose: incoming, spaceID: UUID())

        #expect(mock.updatedPropose?.counterpartySignSignature == "newSig")
        #expect(mock.updatedPropose?.counterpartySignTimestamp == "2026-01-01T00:00:00Z")
    }

    @Test func testLocalSignaturePreservedWhenIncomingIsNil() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, counterpartySignSignature: "existingSig", counterpartySignTimestamp: "2026-01-01T00:00:00Z")
        let useCase = makeUseCase(proposeRepository: mock)
        let incoming = makePropose(id: proposeID, counterpartySignSignature: nil, counterpartySignTimestamp: nil)

        try useCase.execute(propose: incoming, spaceID: UUID())

        #expect(mock.updatedPropose?.counterpartySignSignature == "existingSig")
        #expect(mock.updatedPropose?.counterpartySignTimestamp == "2026-01-01T00:00:00Z")
    }

    @Test func testIncomingFinalStatusIsMerged() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, finalStatus: nil)
        let useCase = makeUseCase(proposeRepository: mock)

        try useCase.execute(propose: makePropose(id: proposeID, finalStatus: .honored), spaceID: UUID())

        #expect(mock.updatedPropose?.finalStatus == .honored)
    }

    @Test func testLocalFinalStatusPreservedWhenIncomingIsNil() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, finalStatus: .honored)
        let useCase = makeUseCase(proposeRepository: mock)

        try useCase.execute(propose: makePropose(id: proposeID, finalStatus: nil), spaceID: UUID())

        #expect(mock.updatedPropose?.finalStatus == .honored)
    }

    @Test func testUpdateErrorThrowsFailedToSave() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID)
        mock.updateError = NSError(domain: "test", code: 1)
        let useCase = makeUseCase(proposeRepository: mock)

        #expect(throws: ImportProposeUseCaseError.failedToSave) {
            try useCase.execute(propose: makePropose(id: proposeID), spaceID: UUID())
        }
    }

    // MARK: - Signature verification

    @Test func testInvalidCreatorSignatureThrowsInvalidSignature() throws {
        let mockKeychain = MockKeychainRepository()
        mockKeychain.verifySignatureResult = false
        let useCase = makeUseCase(keychainRepository: mockKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(propose: makePropose(), spaceID: UUID())
        }
    }

    @Test func testInvalidCounterpartySignSignatureThrowsInvalidSignature() throws {
        // creator passes, counterparty sign fails
        let failingKeychain = MockKeychainRepositoryWithCallCount()
        failingKeychain.resultsPerCall = [true, false]  // creator: pass, sign: fail

        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID)
        let useCase = ImportProposeUseCaseImpl(
            proposeRepository: mock,
            keychainRepository: failingKeychain
        )
        let incoming = makePropose(
            id: proposeID,
            counterpartySignSignature: "fakeSig",
            counterpartySignTimestamp: "2026-01-01T00:00:00Z"
        )

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(propose: incoming, spaceID: UUID())
        }
    }

    @Test func testMissingTimestampWithSignatureThrowsInvalidSignature() throws {
        // counterpartySignSignature present but counterpartySignTimestamp is nil
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID)
        let useCase = makeUseCase(proposeRepository: mock)
        let incoming = makePropose(
            id: proposeID,
            counterpartySignSignature: "someSig",
            counterpartySignTimestamp: nil  // timestamp missing — invalid
        )

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(propose: incoming, spaceID: UUID())
        }
    }

    @Test func testVerifySignatureThrowingTreatedAsInvalid() throws {
        let mockKeychain = MockKeychainRepository()
        mockKeychain.verifySignatureError = NSError(domain: "test", code: 1)
        let useCase = makeUseCase(keychainRepository: mockKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(propose: makePropose(), spaceID: UUID())
        }
    }

    // MARK: - signatureVersion preservation

    @Test func testSignatureVersionPreservedInMerge() throws {
        let mock = MockProposeRepository()
        let proposeID = UUID()
        mock.fetchByIDResult = makePropose(id: proposeID, signatureVersion: 2)
        let useCase = makeUseCase(proposeRepository: mock)

        try useCase.execute(propose: makePropose(id: proposeID), spaceID: UUID())

        #expect(mock.updatedPropose?.signatureVersion == 2)
    }

    // MARK: - Counterparty honor/part signature verification

    @Test func testInvalidCounterpartyHonorSignatureThrowsInvalidSignature() throws {
        // creator: pass, counterparty sign: pass, counterparty honor: fail
        let failingKeychain = MockKeychainRepositoryWithCallCount()
        failingKeychain.resultsPerCall = [true, true, false]
        let useCase = makeUseCase(keychainRepository: failingKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    counterpartySignSignature: "signSig",
                    counterpartySignTimestamp: "2026-01-01T00:00:00Z",
                    counterpartyHonorSignature: "fakeSig",
                    counterpartyHonorTimestamp: "2026-01-02T00:00:00Z"
                ),
                spaceID: UUID()
            )
        }
    }

    @Test func testMissingCounterpartyHonorTimestampThrowsInvalidSignature() throws {
        let mockKeychain = MockKeychainRepository()
        mockKeychain.verifySignatureResult = true
        let useCase = makeUseCase(keychainRepository: mockKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    counterpartyHonorSignature: "someSig",
                    counterpartyHonorTimestamp: nil
                ),
                spaceID: UUID()
            )
        }
    }

    @Test func testInvalidCounterpartyPartSignatureThrowsInvalidSignature() throws {
        // creator: pass, counterparty sign: pass, counterparty part: fail
        let failingKeychain = MockKeychainRepositoryWithCallCount()
        failingKeychain.resultsPerCall = [true, true, false]
        let useCase = makeUseCase(keychainRepository: failingKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    counterpartySignSignature: "signSig",
                    counterpartySignTimestamp: "2026-01-01T00:00:00Z",
                    counterpartyPartSignature: "fakeSig",
                    counterpartyPartTimestamp: "2026-01-02T00:00:00Z"
                ),
                spaceID: UUID()
            )
        }
    }

    @Test func testMissingCounterpartyPartTimestampThrowsInvalidSignature() throws {
        let mockKeychain = MockKeychainRepository()
        mockKeychain.verifySignatureResult = true
        let useCase = makeUseCase(keychainRepository: mockKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    counterpartyPartSignature: "someSig",
                    counterpartyPartTimestamp: nil
                ),
                spaceID: UUID()
            )
        }
    }

    // MARK: - Creator honor/part signature verification

    @Test func testInvalidCreatorHonorSignatureThrowsInvalidSignature() throws {
        // creator: pass, counterparty sign: pass, creator honor: fail
        let failingKeychain = MockKeychainRepositoryWithCallCount()
        failingKeychain.resultsPerCall = [true, true, false]
        let useCase = makeUseCase(keychainRepository: failingKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    counterpartySignSignature: "signSig",
                    counterpartySignTimestamp: "2026-01-01T00:00:00Z",
                    creatorHonorSignature: "fakeSig",
                    creatorHonorTimestamp: "2026-01-02T00:00:00Z"
                ),
                spaceID: UUID()
            )
        }
    }

    @Test func testMissingCreatorHonorTimestampThrowsInvalidSignature() throws {
        let mockKeychain = MockKeychainRepository()
        mockKeychain.verifySignatureResult = true
        let useCase = makeUseCase(keychainRepository: mockKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    creatorHonorSignature: "someSig",
                    creatorHonorTimestamp: nil
                ),
                spaceID: UUID()
            )
        }
    }

    @Test func testInvalidCreatorPartSignatureThrowsInvalidSignature() throws {
        // creator: pass, counterparty sign: pass, creator part: fail
        let failingKeychain = MockKeychainRepositoryWithCallCount()
        failingKeychain.resultsPerCall = [true, true, false]
        let useCase = makeUseCase(keychainRepository: failingKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    counterpartySignSignature: "signSig",
                    counterpartySignTimestamp: "2026-01-01T00:00:00Z",
                    creatorPartSignature: "fakeSig",
                    creatorPartTimestamp: "2026-01-02T00:00:00Z"
                ),
                spaceID: UUID()
            )
        }
    }

    @Test func testMissingCreatorPartTimestampThrowsInvalidSignature() throws {
        let mockKeychain = MockKeychainRepository()
        mockKeychain.verifySignatureResult = true
        let useCase = makeUseCase(keychainRepository: mockKeychain)

        #expect(throws: ImportProposeUseCaseError.invalidSignature) {
            try useCase.execute(
                propose: makePropose(
                    creatorPartSignature: "someSig",
                    creatorPartTimestamp: nil
                ),
                spaceID: UUID()
            )
        }
    }
}

// MARK: - Helper mock for per-call results

/// MockKeychainRepository variant that returns different results per verifySignature call
final class MockKeychainRepositoryWithCallCount: MockKeychainRepository {
    var resultsPerCall: [Bool] = []
    private var callIndex = 0

    override func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool {
        if let error = verifySignatureError { throw error }
        defer { callIndex += 1 }
        guard callIndex < resultsPerCall.count else { return verifySignatureResult }
        return resultsPerCall[callIndex]
    }
}
