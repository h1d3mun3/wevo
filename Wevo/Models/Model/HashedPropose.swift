//
//  HashedPropose.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// API通信用のProposeモデル
/// ハッシュ化されたメッセージのみを持つ（元のメッセージは含まない）
struct HashedPropose: Codable, Identifiable {
    let id: UUID
    let payloadHash: String
    let signatures: [Signature]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case payloadHash = "payloadHash"
        case signatures
        case createdAt = "createdAt"
    }
    
    init(
        id: UUID,
        payloadHash: String,
        signatures: [Signature],
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.payloadHash = payloadHash
        self.signatures = signatures
        self.createdAt = createdAt
    }
}
