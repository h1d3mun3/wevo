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

    /// テスト用Proposeを生成するヘルパー
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

    @Test("Creatorは常にtrueを返す")
    func returnsTrueForCreator() {
        let identity = Identity(id: UUID(), nickname: "Alice", publicKey: creatorPublicKey)
        let propose = makePropose(counterpartySignSignature: nil)

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert: Creatorは常に署名済み
        #expect(result == true)
    }

    @Test("CounterpartyはcounterpartySignSignatureがある場合trueを返す")
    func returnsTrueForCounterpartyWhenSigned() {
        let identity = Identity(id: UUID(), nickname: "Bob", publicKey: counterpartyPublicKey)
        let propose = makePropose(counterpartySignSignature: "someSig")

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == true)
    }

    @Test("CounterpartyはcounterpartySignSignatureがnilの場合falseを返す")
    func returnsFalseForCounterpartyWhenNotSigned() {
        let identity = Identity(id: UUID(), nickname: "Bob", publicKey: counterpartyPublicKey)
        let propose = makePropose(counterpartySignSignature: nil)

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == false)
    }

    @Test("参加者でないIdentityはfalseを返す")
    func returnsFalseForNonParticipant() {
        let identity = Identity(id: UUID(), nickname: "Eve", publicKey: "unrelatedKey")
        let propose = makePropose(counterpartySignSignature: "someSig")

        // Act
        let result = useCase.execute(identity: identity, propose: propose)

        // Assert
        #expect(result == false)
    }
}
