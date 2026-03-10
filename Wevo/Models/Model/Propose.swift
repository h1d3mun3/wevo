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
    let spaceID: UUID
    let message: String // 元のメッセージ（ローカルのみ）
    let payloadHash: String // ハッシュ化されたメッセージ
    let signatures: [Signature]
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        spaceID: UUID,
        message: String,
        signatures: [Signature],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.spaceID = spaceID
        self.message = message
        self.payloadHash = message.sha256HashedString
        self.signatures = signatures
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
