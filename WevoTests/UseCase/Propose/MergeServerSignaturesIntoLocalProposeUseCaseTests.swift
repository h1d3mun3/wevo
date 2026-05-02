//
//  MergeServerSignaturesIntoLocalProposeUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct MergeServerSignaturesIntoLocalProposeUseCaseTests {

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

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

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

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

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

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

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

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

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
        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

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

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(proposeID: proposeID, serverPropose: makeServerPropose(proposeID: proposeID))
        }
    }

    @Test func testPreservesLocalHonorSignaturesWhenServerReturnsNil() throws {
        // Arrange: local propose already has honor signatures
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: "signSig",
            counterpartyHonorSignature: "localHonorSig",
            counterpartyHonorTimestamp: "2026-03-01T00:00:00Z",
            creatorHonorSignature: "localCreatorHonorSig",
            creatorHonorTimestamp: "2026-03-01T00:00:01Z",
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose

        // Server returns nil for honor signatures (e.g. delayed processing)
        let serverPropose = HashedPropose(
            id: proposeID,
            contentHash: "hash",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterparties: [ProposeCounterparty(
                publicKey: "counterpartyKey",
                signSignature: "signSig",
                signTimestamp: "2026-02-01T00:00:00Z",
                honorSignature: nil,
                honorTimestamp: nil,
                partSignature: nil,
                partTimestamp: nil
            )],
            status: .signed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, serverPropose: serverPropose)

        // Assert: local honor signatures are preserved
        #expect(mockRepository.updatedPropose?.counterpartyHonorSignature == "localHonorSig")
        #expect(mockRepository.updatedPropose?.counterpartyHonorTimestamp == "2026-03-01T00:00:00Z")
        #expect(mockRepository.updatedPropose?.creatorHonorSignature == "localCreatorHonorSig")
        #expect(mockRepository.updatedPropose?.creatorHonorTimestamp == "2026-03-01T00:00:01Z")
    }

    @Test func testPreservesLocalPartSignaturesWhenServerReturnsNil() throws {
        // Arrange: local propose already has part signatures
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: "signSig",
            counterpartyPartSignature: "localPartSig",
            counterpartyPartTimestamp: "2026-03-01T00:00:00Z",
            creatorPartSignature: "localCreatorPartSig",
            creatorPartTimestamp: "2026-03-01T00:00:01Z",
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose

        // Server returns nil for part signatures
        let serverPropose = HashedPropose(
            id: proposeID,
            contentHash: "hash",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterparties: [ProposeCounterparty(
                publicKey: "counterpartyKey",
                signSignature: "signSig",
                signTimestamp: "2026-02-01T00:00:00Z",
                honorSignature: nil,
                honorTimestamp: nil,
                partSignature: nil,
                partTimestamp: nil
            )],
            status: .signed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, serverPropose: serverPropose)

        // Assert: local part signatures are preserved
        #expect(mockRepository.updatedPropose?.counterpartyPartSignature == "localPartSig")
        #expect(mockRepository.updatedPropose?.counterpartyPartTimestamp == "2026-03-01T00:00:00Z")
        #expect(mockRepository.updatedPropose?.creatorPartSignature == "localCreatorPartSig")
        #expect(mockRepository.updatedPropose?.creatorPartTimestamp == "2026-03-01T00:00:01Z")
    }

    @Test func testPreservesLocalCreatorDissolveTimestampWhenServerReturnsNil() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            creatorDissolveSignature: "creatorDissolveSig",
            creatorDissolveTimestamp: "2026-03-01T00:00:00Z",
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose

        let serverPropose = HashedPropose(
            id: proposeID,
            contentHash: "hash",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterparties: [],
            creatorDissolveSignature: nil,
            creatorDissolveTimestamp: nil,
            status: .proposed,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)
        try useCase.execute(proposeID: proposeID, serverPropose: serverPropose)

        #expect(mockRepository.updatedPropose?.creatorDissolveSignature == "creatorDissolveSig")
        #expect(mockRepository.updatedPropose?.creatorDissolveTimestamp == "2026-03-01T00:00:00Z")
    }

    @Test func testPreservesLocalSignatureVersion() throws {
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            signatureVersion: 2,
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = existingPropose

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)
        try useCase.execute(proposeID: proposeID, serverPropose: makeServerPropose(proposeID: proposeID))

        #expect(mockRepository.updatedPropose?.signatureVersion == 2)
    }

    @Test func testServerHonorSignatureOverridesNilLocal() throws {
        // Arrange: local has no honor sig, server provides one
        let mockRepository = MockProposeRepository()
        let proposeID = UUID()
        let existingPropose = makePropose(id: proposeID)
        mockRepository.fetchByIDResult = existingPropose

        let serverPropose = HashedPropose(
            id: proposeID,
            contentHash: "hash",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterparties: [ProposeCounterparty(
                publicKey: "counterpartyKey",
                signSignature: "serverSig123",
                signTimestamp: "2026-01-02T00:00:00Z",
                honorSignature: "serverHonorSig",
                honorTimestamp: "2026-03-10T00:00:00Z",
                partSignature: nil,
                partTimestamp: nil
            )],
            status: .honored,
            createdAt: .now,
            updatedAt: .now
        )

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        try useCase.execute(proposeID: proposeID, serverPropose: serverPropose)

        // Assert: server honor sig is applied
        #expect(mockRepository.updatedPropose?.counterpartyHonorSignature == "serverHonorSig")
        #expect(mockRepository.updatedPropose?.counterpartyHonorTimestamp == "2026-03-10T00:00:00Z")
    }
}
