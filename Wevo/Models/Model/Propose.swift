//
//  Propose.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import Foundation
import CryptoKit

/// ローカルストレージ用のProposeモデル
/// 元のメッセージとハッシュ化されたメッセージの両方を持つ
struct Propose: Codable, Identifiable {
    let id: UUID
    let message: String // 元のメッセージ（ローカルのみ）
    let payloadHash: String // ハッシュ化されたメッセージ
    let signatures: [Signature]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case payloadHash = "payloadHash"
        case signatures
        case createdAt = "createdAt"
    }
    
    /// メッセージから自動的にハッシュを生成するイニシャライザ
    init(
        id: UUID = UUID(),
        message: String,
        signatures: [Signature] = [],
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.message = message
        self.payloadHash = Self.hashMessage(message)
        self.signatures = signatures
        self.createdAt = createdAt
    }
    
    /// 完全なイニシャライザ（デコード時などに使用）
    init(
        id: UUID,
        message: String,
        payloadHash: String,
        signatures: [Signature],
        createdAt: Date?
    ) {
        self.id = id
        self.message = message
        self.payloadHash = payloadHash
        self.signatures = signatures
        self.createdAt = createdAt
    }
    
    /// メッセージをSHA-256でハッシュ化
    static func hashMessage(_ message: String) -> String {
        let data = Data(message.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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
