//
//  HasIdentitySignedProposeUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol HasIdentitySignedProposeUseCase {
    /// 指定したIdentityがProposeに署名済みかどうかを返す
    /// - Creator: 常にtrue（Propose作成時に必ず署名する）
    /// - Counterparty: counterpartySignSignatureが存在する場合にtrue
    func execute(identity: Identity, propose: Propose) -> Bool
}

struct HasIdentitySignedProposeUseCaseImpl: HasIdentitySignedProposeUseCase {
    func execute(identity: Identity, propose: Propose) -> Bool {
        let myPublicKey = identity.publicKey

        // Creatorは常に署名済み（Propose作成時に必ず署名するため）
        if myPublicKey == propose.creatorPublicKey {
            return true
        }

        // CounterpartyはcounterpartySignSignatureの有無で判定
        if myPublicKey == propose.counterpartyPublicKey {
            return propose.counterpartySignSignature != nil
        }

        // 参加者でない場合はfalse
        return false
    }
}
