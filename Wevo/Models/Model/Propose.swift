//
//  Propose.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import Foundation

struct Propose: Codable, Identifiable {
    let id: UUID
    let payloadHash: String
    let signatures: [Signature]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case payloadHash = "payloadHash"
        case signatures
        case createdAt = "created_at"
    }
}
