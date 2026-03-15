//
//  HasIdentitySignedProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

struct HasIdentitySignedProposeUseCaseTests {

    let creatorPublicKey = "CreatorPublicKey"
    let counterpartyPublicKey = "CounterpartyPublicKey"
    let useCase = HasIdentitySignedProposeUseCaseImpl()

    /// Helper to generate a test Propose
    private func makePropose(counterpartySignSignature: String?) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test("Creator always returns true")
    func returnsTrueForCreator() {
        let identity = Identity(id: UUID(), nickname: "Alice", publicKey: creatorPublicKey)
        let propose = makePropose(counterpartySignSignature: nil)

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert: Creator is always considered signed
        #expect(result == true)
    }

    @Test("Counterparty returns true when counterpartySignSignature exists")
    func returnsTrueForCounterpartyWhenSigned() {
        let identity = Identity(id: UUID(), nickname: "Bob", publicKey: counterpartyPublicKey)
        let propose = makePropose(counterpartySignSignature: "someSig")

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == true)
    }

    @Test("Counterparty returns false when counterpartySignSignature is nil")
    func returnsFalseForCounterpartyWhenNotSigned() {
        let identity = Identity(id: UUID(), nickname: "Bob", publicKey: counterpartyPublicKey)
        let propose = makePropose(counterpartySignSignature: nil)

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == false)
    }

    @Test("Identity that is not a participant returns false")
    func returnsFalseForNonParticipant() {
        let identity = Identity(id: UUID(), nickname: "Eve", publicKey: "unrelatedKey")
        let propose = makePropose(counterpartySignSignature: "someSig")

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == false)
    }
}
