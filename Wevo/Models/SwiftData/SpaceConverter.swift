//
//  SpaceConverter.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation

/// Space構造体とSpaceModelの相互変換を行う
struct SpaceConverter {
    
    /// Space構造体からSpaceModelへ変換
    static func toModel(from space: Space) -> SpaceSwiftData {
        return SpaceSwiftData(
            id: space.id,
            name: space.name,
            urlString: space.url,
            defaultIdentityID: space.defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: space.updatedAt
        )
    }
    
    /// SpaceModelからSpace構造体へ変換
    static func toEntity(from model: SpaceSwiftData) -> Space {
        return Space(
            id: model.id,
            name: model.name,
            url: model.urlString,
            defaultIdentityID: model.defaultIdentityID,
            orderIndex: model.orderIndex,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
    
    /// 複数のSpaceModelを変換
    static func toEntities(from models: [SpaceSwiftData]) -> [Space] {
        return models.map { model in
            toEntity(from: model)
        }
    }
    
    /// SpaceModelを既存のSpace構造体で更新
    static func updateModel(_ model: SpaceSwiftData, with space: Space) {
        model.name = space.name
        model.urlString = space.url
        model.defaultIdentityID = space.defaultIdentityID
        model.orderIndex = space.orderIndex
        model.updatedAt = Date()
    }
}
