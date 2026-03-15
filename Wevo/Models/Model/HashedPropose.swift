//
//  HashedPropose.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// Counterpartyの情報を表す構造体（APIレスポンス内のcounterpartiesフィールドに対応）
struct ProposeCounterparty: Codable {
    /// CounterpartyのBase64 x963形式の公開鍵
    let publicKey: String
    /// Counterpartyの署名署名（nil = 未署名）
    let signSignature: String?
    /// Counterpartyのhonor署名（nil = 未実行）
    let honorSignature: String?
    /// Counterpartyのpart署名（nil = 未実行）
    let partSignature: String?
}

/// API通信用のProposeモデル
/// ハッシュ化されたメッセージのみを持つ（元のメッセージは含まない）
/// サーバーのProposeResponseに対応
struct HashedPropose: Codable, Identifiable {
    let id: UUID
    /// SHA256ハッシュ（APIではcontentHashとして受け取るが、内部ではpayloadHashとして扱う）
    let contentHash: String
    /// Creatorの公開鍵（Base64 x963）
    let creatorPublicKey: String
    /// Creatorが作成時に付与した署名（Base64 DER）
    let creatorSignature: String
    /// Counterpartyのリスト（PoCでは1名のみ）
    let counterparties: [ProposeCounterparty]
    /// Creatorのhonor署名（nil = 未実行）
    let honorCreatorSignature: String?
    /// Creatorのpart署名（nil = 未実行）
    let partCreatorSignature: String?
    /// サーバーが管理するステータス（参考値のみ）
    let status: ProposeStatus
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        contentHash: String,
        creatorPublicKey: String,
        creatorSignature: String,
        counterparties: [ProposeCounterparty],
        honorCreatorSignature: String? = nil,
        partCreatorSignature: String? = nil,
        status: ProposeStatus = .proposed,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.contentHash = contentHash
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterparties = counterparties
        self.honorCreatorSignature = honorCreatorSignature
        self.partCreatorSignature = partCreatorSignature
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
