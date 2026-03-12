//
//  ContactConverter.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation

/// Contact構造体とContactSwiftDataの相互変換を行う
struct ContactConverter {

    /// Contact構造体からContactSwiftDataへ変換
    static func toModel(from contact: Contact) -> ContactSwiftData {
        return ContactSwiftData(
            id: contact.id,
            nickname: contact.nickname,
            publicKey: contact.publicKey,
            createdAt: contact.createdAt
        )
    }

    /// ContactSwiftDataからContact構造体へ変換
    static func toEntity(from model: ContactSwiftData) -> Contact {
        return Contact(
            id: model.id,
            nickname: model.nickname,
            publicKey: model.publicKey,
            createdAt: model.createdAt
        )
    }

    /// 複数のContactSwiftDataを変換
    static func toEntities(from models: [ContactSwiftData]) -> [Contact] {
        return models.map { toEntity(from: $0) }
    }

    /// ContactSwiftDataを既存のContact構造体で更新
    static func updateModel(_ model: ContactSwiftData, with contact: Contact) {
        model.nickname = contact.nickname
        model.publicKey = contact.publicKey
    }
}
