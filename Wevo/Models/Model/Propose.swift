//
//  Propose.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import Foundation

/// ローカルストレージ用のProposeモデル
/// 元のメッセージとハッシュ化されたメッセージの両方を持つ
/// ステータスはローカルの署名有無からcomputed propertyで導出する（サーバーのstatusは参考値のみ）
struct Propose: Codable, Identifiable {
    let id: UUID
    let spaceID: UUID
    let message: String            // 元のメッセージ（ローカルのみ）
    let payloadHash: String        // SHA256ハッシュ（APIでは contentHash として送信）
    let createdAt: Date
    let updatedAt: Date

    // MARK: - 参加者（1:1 PoC）

    /// Proposeを作成したユーザーの公開鍵（Base64 x963）
    let creatorPublicKey: String

    /// Creatorが作成時に付与した署名（Base64 DER）
    let creatorSignature: String

    /// Counterpartyの公開鍵（Base64 x963）
    let counterpartyPublicKey: String

    /// Counterpartyの署名（nilの場合はまだ署名していない）
    let counterpartySignSignature: String?

    // MARK: - ローカルステータス（computed property）

    /// ローカルの署名有無から導出したステータス
    /// サーバーから受け取った status フィールドは参考値のみで、こちらを使う
    var localStatus: ProposeStatus {
        if counterpartySignSignature != nil {
            return .signed
        }
        return .proposed
    }

    init(
        id: UUID,
        spaceID: UUID,
        message: String,
        creatorPublicKey: String,
        creatorSignature: String,
        counterpartyPublicKey: String,
        counterpartySignSignature: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.spaceID = spaceID
        self.message = message
        // SHA256ハッシュを自動計算して payloadHash に格納
        self.payloadHash = message.sha256HashedString
        self.creatorPublicKey = creatorPublicKey
        self.creatorSignature = creatorSignature
        self.counterpartyPublicKey = counterpartyPublicKey
        self.counterpartySignSignature = counterpartySignSignature
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
