//
//  SignatureSwiftData.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

/// SwiftDataで永続化する署名モデル
/// ProposeSwiftDataとのリレーションは削除（新APIではPropose内に直接署名データを格納する）
@Model
final class SignatureSwiftData {
    var id: UUID = UUID()
    var publicKey: String = ""
    var signatureData: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID,
        publicKey: String,
        signatureData: String,
        createdAt: Date
    ) {
        self.id = id
        self.publicKey = publicKey
        self.signatureData = signatureData
        self.createdAt = createdAt
    }
}
