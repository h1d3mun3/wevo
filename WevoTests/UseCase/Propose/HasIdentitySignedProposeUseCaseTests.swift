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

    let identity = Identity(
        id: UUID(),
        nickname: "My Key",
        publicKey: "MyPublicKey123"
    )

    let useCase = HasIdentitySignedProposeUseCaseImpl()

    @Test("ローカル署名に自分の署名がある場合trueを返す")
    func returnsTrueWhenLocalSignatureExists() {
        let signatures = [
            Signature(id: UUID(), publicKey: "OtherKey", signature: "sig1", createdAt: .now),
            Signature(id: UUID(), publicKey: "MyPublicKey123", signature: "sig2", createdAt: .now),
        ]

        let result = useCase.execute(identity: identity, proposeSignatures: signatures, serverSignatures: [])
        #expect(result == true)
    }

    @Test("サーバー署名に自分の署名がある場合trueを返す")
    func returnsTrueWhenServerSignatureExists() {
        let localSignatures = [
            Signature(id: UUID(), publicKey: "OtherKey", signature: "sig1", createdAt: .now),
        ]
        let serverSignatures = [
            Signature(id: UUID(), publicKey: "MyPublicKey123", signature: "sig2", createdAt: .now),
        ]

        let result = useCase.execute(identity: identity, proposeSignatures: localSignatures, serverSignatures: serverSignatures)
        #expect(result == true)
    }

    @Test("どこにも自分の署名がない場合falseを返す")
    func returnsFalseWhenNoSignatureExists() {
        let signatures = [
            Signature(id: UUID(), publicKey: "OtherKey1", signature: "sig1", createdAt: .now),
            Signature(id: UUID(), publicKey: "OtherKey2", signature: "sig2", createdAt: .now),
        ]

        let result = useCase.execute(identity: identity, proposeSignatures: signatures, serverSignatures: [])
        #expect(result == false)
    }

    @Test("署名が空の場合falseを返す")
    func returnsFalseWhenNoSignatures() {
        let result = useCase.execute(identity: identity, proposeSignatures: [], serverSignatures: [])
        #expect(result == false)
    }
}
