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
    let signatureData: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case publicKey = "public_key"
        case signatureData = "signature_data"
        case createdAt = "created_at"
    }
}
