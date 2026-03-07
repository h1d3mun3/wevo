//
//  Propose.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import Foundation

/// ローカルストレージ用のProposeモデル
/// 元のメッセージとハッシュ化されたメッセージの両方を持つ
struct Propose: Codable, Identifiable {
    let id: UUID
    let message: String // 元のメッセージ（ローカルのみ）
    let payloadHash: String // ハッシュ化されたメッセージ
    let signatures: [Signature]
    let createdAt: Date
    let updatedAt: Date
    
    /// メッセージから自動的にハッシュを生成するイニシャライザ
    init(
        id: UUID,
        message: String,
        signatures: [Signature],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.message = message
        self.payloadHash = message.sha256HashedString
        self.signatures = signatures
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// API送信用のHashedProposeに変換
    func toHashedPropose() -> HashedPropose {
        return HashedPropose(
            id: id,
            payloadHash: payloadHash,
            signatures: signatures,
            createdAt: createdAt
        )
    }
}
