//
//  SpaceConverter.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation

enum SpaceConverterError: Error {
    case invalidURL(String)
}

/// Space構造体とSpaceModelの相互変換を行う
struct SpaceConverter {
    
    /// Space構造体からSpaceModelへ変換
    static func toModel(from space: Space) -> SpaceSwiftData {
        return SpaceSwiftData(
            id: space.id,
            name: space.name,
            serverURLString: space.serverURL.url?.absoluteString ?? "",
            activeIdentityID: space.activeIdentityID,
            orderIndex: space.orderIndex
        )
    }
    
    /// SpaceModelからSpace構造体へ変換
    static func toEntity(from model: SpaceSwiftData) throws -> Space {
        guard let url = URL(string: model.serverURLString) else {
            throw SpaceConverterError.invalidURL(model.serverURLString)
        }
        
        let urlRequest = URLRequest(url: url)
        
        return Space(
            id: model.id,
            name: model.name,
            serverURL: urlRequest,
            activeIdentityID: model.activeIdentityID,
            orderIndex: model.orderIndex
        )
    }
    
    /// 複数のSpaceModelを変換（失敗したものは除外）
    static func toEntities(from models: [SpaceSwiftData]) -> [Space] {
        return models.compactMap { model in
            try? toEntity(from: model)
        }
    }
    
    /// SpaceModelを既存のSpace構造体で更新
    static func updateModel(_ model: SpaceSwiftData, with space: Space) {
        model.name = space.name
        model.serverURLString = space.serverURL.url?.absoluteString ?? ""
        model.activeIdentityID = space.activeIdentityID
        model.orderIndex = space.orderIndex
        model.updatedAt = Date()
    }
}
