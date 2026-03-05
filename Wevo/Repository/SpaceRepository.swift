//
//  SpaceRepository.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation
import SwiftData

enum SpaceRepositoryError: Error {
    case spaceNotFound(UUID)
    case conversionError(Error)
    case saveError(Error)
    case deleteError(Error)
    case fetchError(Error)
}

/// SwiftDataを使用してSpaceのCRUD操作を提供するRepository
@MainActor
final class SpaceRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Create
    
    /// 新しいSpaceを作成
    func create(_ space: Space) throws {
        let model = SpaceConverter.toModel(from: space)
        modelContext.insert(model)
        
        do {
            try modelContext.save()
        } catch {
            throw SpaceRepositoryError.saveError(error)
        }
    }
    
    // MARK: - Read
    
    /// すべてのSpaceを取得（orderIndexでソート）
    func fetchAll() throws -> [Space] {
        let descriptor = FetchDescriptor<SpaceSwiftData>(
            sortBy: [SortDescriptor(\.orderIndex, order: .forward)]
        )
        
        do {
            let models = try modelContext.fetch(descriptor)
            return SpaceConverter.toEntities(from: models)
        } catch {
            throw SpaceRepositoryError.fetchError(error)
        }
    }
    
    /// 特定のIDのSpaceを取得
    func fetch(by id: UUID) throws -> Space {
        let predicate = #Predicate<SpaceSwiftData> { model in
            model.id == id
        }
        
        var descriptor = FetchDescriptor<SpaceSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw SpaceRepositoryError.spaceNotFound(id)
            }
            
            do {
                return try SpaceConverter.toEntity(from: model)
            } catch {
                throw SpaceRepositoryError.conversionError(error)
            }
        } catch {
            throw SpaceRepositoryError.fetchError(error)
        }
    }
    
    // MARK: - Update
    
    /// 既存のSpaceを更新
    func update(_ space: Space) throws {
        let spaceID = space.id
        let predicate = #Predicate<SpaceSwiftData> { model in
            model.id == spaceID
        }
        
        var descriptor = FetchDescriptor<SpaceSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw SpaceRepositoryError.spaceNotFound(space.id)
            }
            
            SpaceConverter.updateModel(model, with: space)
            
            try modelContext.save()
        } catch let error as SpaceRepositoryError {
            throw error
        } catch {
            throw SpaceRepositoryError.saveError(error)
        }
    }
    
    // MARK: - Delete
    /// 特定のIDのSpaceを削除
    func delete(by id: UUID) throws {
        let predicate = #Predicate<SpaceSwiftData> { model in
            model.id == id
        }
        
        var descriptor = FetchDescriptor<SpaceSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw SpaceRepositoryError.spaceNotFound(id)
            }
            
            modelContext.delete(model)
            try modelContext.save()
        } catch let error as SpaceRepositoryError {
            throw error
        } catch {
            throw SpaceRepositoryError.deleteError(error)
        }
    }
    
    /// すべてのSpaceを削除
    func deleteAll() throws {
        do {
            try modelContext.delete(model: SpaceSwiftData.self)
            try modelContext.save()
        } catch {
            throw SpaceRepositoryError.deleteError(error)
        }
    }
}
