//
//  CanSignProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/17/26.
//

import Testing
import Foundation
@testable import Wevo

struct CanSignProposeUseCaseTests {

    private let counterpartyPublicKey = "counterpartyPubKey"
    private let creatorPublicKey = "creatorPubKey"

    private func makePropose(
        counterpartyPublicKey: String,
        counterpartySignSignature: String? = nil
    ) -> Propose {
        Propose(
            id: UUID(),
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

    @Test func testReturnsTrueWhenIdentityIsCounterpartyAndStatusIsProposed() {
        // Arrange
        let identity = Identity(id: UUID(), nickname: "Counterparty", publicKey: counterpartyPublicKey)
        let propose = makePropose(counterpartyPublicKey: counterpartyPublicKey, counterpartySignSignature: nil)
        let useCase = CanSignProposeUseCaseImpl()

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == true)
    }

    @Test func testReturnsFalseWhenIdentityIsNotCounterparty() {
        // Arrange
        let identity = Identity(id: UUID(), nickname: "Creator", publicKey: creatorPublicKey)
        let propose = makePropose(counterpartyPublicKey: counterpartyPublicKey, counterpartySignSignature: nil)
        let useCase = CanSignProposeUseCaseImpl()

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == false)
    }

    @Test func testReturnsFalseWhenProposeIsAlreadySigned() {
        // Arrange
        let identity = Identity(id: UUID(), nickname: "Counterparty", publicKey: counterpartyPublicKey)
        let propose = makePropose(counterpartyPublicKey: counterpartyPublicKey, counterpartySignSignature: "existingSig")
        let useCase = CanSignProposeUseCaseImpl()

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert: localStatus is .signed, so cannot sign again
        #expect(result == false)
    }

    @Test func testReturnsFalseWhenProposeIsHonored() {
        // Arrange: honored state requires both creator and counterparty honor signatures
        let identity = Identity(id: UUID(), nickname: "Counterparty", publicKey: counterpartyPublicKey)
        let propose = Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: "sig",
            counterpartyHonorSignature: "counterpartyHonorSig",
            counterpartyHonorTimestamp: "2026-01-02T00:00:00Z",
            creatorHonorSignature: "creatorHonorSig",
            creatorHonorTimestamp: "2026-01-03T00:00:00Z",
            createdAt: .now,
            updatedAt: .now
        )
        let useCase = CanSignProposeUseCaseImpl()

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert: localStatus is .honored, so cannot sign
        #expect(result == false)
    }

    @Test func testReturnsFalseWhenPublicKeyDoesNotMatchCounterparty() {
        // Arrange
        let identity = Identity(id: UUID(), nickname: "Stranger", publicKey: "strangerPubKey")
        let propose = makePropose(counterpartyPublicKey: counterpartyPublicKey, counterpartySignSignature: nil)
        let useCase = CanSignProposeUseCaseImpl()

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == false)
    }
}
