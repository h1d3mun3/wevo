//
//  Signature.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import Foundation

/// 署名データ
struct Signature: Codable, Identifiable {
    let id: UUID
    let publicKey: String
    let signature: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case publicKey = "publicKey"
        case signature = "signatureData"
        case createdAt = "createdAt"
    }
}
