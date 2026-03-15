//
//  ProposeSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

/// SwiftDataで永続化するProposeモデル
/// CloudKit互換のためオプショナルまたはデフォルト値を持つ必要がある
@Model
final class ProposeSwiftData {
    var id: UUID = UUID()
    var message: String = ""       // 元のメッセージ
    var payloadHash: String = ""   // SHA256ハッシュ（APIでは contentHash として送信）
    var spaceID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - 参加者フィールド（1:1 PoC）

    /// Creatorの公開鍵（Base64 x963）
    var creatorPublicKey: String = ""

    /// Creatorが作成時に付与した署名（Base64 DER）
    var creatorSignature: String = ""

    /// Counterpartyの公開鍵（Base64 x963）
    var counterpartyPublicKey: String = ""

    /// Counterpartyの署名（nil = 未署名）
    var counterpartySignSignature: String? = nil

    init(
        id: UUID,
        message: String,
        payloadHash: String,
        spaceID: UUID,
        creatorPublicKey: String,
        creatorSignature: String,
        counterpartyPublicKey: String,
        counterpartySignSignature: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.message = message
        self.payloadHash = payloadHash
        self.spaceID = spaceID
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterpartyPublicKey = counterpartyPublicKey
        self.counterpartySignSignature = counterpartySignSignature
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
