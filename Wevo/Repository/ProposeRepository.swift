//
//  ProposeRepository.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import SwiftData

enum ProposeRepositoryError: Error {
    case proposeNotFound(UUID)
    case conversionError(Error)
    case saveError(Error)
    case deleteError(Error)
    case fetchError(Error)
}

@MainActor
protocol ProposeRepository {
    func create(_ propose: Propose, spaceID: UUID) throws
    func fetchAll() throws -> [Propose]
    func fetchAll(for spaceID: UUID) throws -> [Propose]
    func fetchAllOrphaned(validSpaceIDs: Set<UUID>) throws -> [Propose]
    func fetch(by id: UUID) throws -> Propose
    func update(_ propose: Propose) throws
    func delete(by id: UUID) throws
    func deleteAll(for spaceID: UUID) throws
}

/// SwiftDataを使用してProposeのCRUD操作を提供するRepository
final class ProposeRepositoryImpl: ProposeRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Create
    
    /// 新しいProposeを作成
    func create(_ propose: Propose, spaceID: UUID) throws {
        let model = ProposeConverter.toModel(from: propose, spaceID: spaceID)
        modelContext.insert(model)
        
        do {
            try modelContext.save()
        } catch {
            throw ProposeRepositoryError.saveError(error)
        }
    }
    
    // MARK: - Read

    /// すべてのProposeを取得（作成日時の降順でソート）
    func fetchAll() throws -> [Propose] {
        let descriptor = FetchDescriptor<ProposeSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            return ProposeConverter.toEntities(from: models)
        } catch {
            throw ProposeRepositoryError.fetchError(error)
        }
    }

    /// 特定のSpaceに属するすべてのProposeを取得（作成日時の降順でソート）
    func fetchAll(for spaceID: UUID) throws -> [Propose] {
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.spaceID == spaceID
        }

        let descriptor = FetchDescriptor<ProposeSwiftData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            return ProposeConverter.toEntities(from: models)
        } catch {
            throw ProposeRepositoryError.fetchError(error)
        }
    }

    /// SpaceIDが有効なセットに含まれないProposeを取得（作成日時の降順でソート）
    func fetchAllOrphaned(validSpaceIDs: Set<UUID>) throws -> [Propose] {
        let predicate = #Predicate<ProposeSwiftData> { model in
            !validSpaceIDs.contains(model.spaceID)
        }

        let descriptor = FetchDescriptor<ProposeSwiftData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            return ProposeConverter.toEntities(from: models)
        } catch {
            throw ProposeRepositoryError.fetchError(error)
        }
    }
    
    /// 特定のIDのProposeを取得
    func fetch(by id: UUID) throws -> Propose {
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.id == id
        }
        
        var descriptor = FetchDescriptor<ProposeSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw ProposeRepositoryError.proposeNotFound(id)
            }
            
            return ProposeConverter.toEntity(from: model)
        } catch {
            throw ProposeRepositoryError.fetchError(error)
        }
    }
    
    // MARK: - Update
    
    /// 既存のProposeを更新
    func update(_ propose: Propose) throws {
        let proposeID = propose.id
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.id == proposeID
        }
        
        var descriptor = FetchDescriptor<ProposeSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw ProposeRepositoryError.proposeNotFound(propose.id)
            }
            
            ProposeConverter.updateModel(model, with: propose)
            
            try modelContext.save()
        } catch let error as ProposeRepositoryError {
            throw error
        } catch {
            throw ProposeRepositoryError.saveError(error)
        }
    }
    
    // MARK: - Delete
    
    /// 特定のIDのProposeを削除
    func delete(by id: UUID) throws {
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.id == id
        }
        
        var descriptor = FetchDescriptor<ProposeSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw ProposeRepositoryError.proposeNotFound(id)
            }
            
            modelContext.delete(model)
            try modelContext.save()
        } catch let error as ProposeRepositoryError {
            throw error
        } catch {
            throw ProposeRepositoryError.deleteError(error)
        }
    }
    
    /// 特定のSpaceに属するすべてのProposeを削除
    func deleteAll(for spaceID: UUID) throws {
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.spaceID == spaceID
        }
        
        let descriptor = FetchDescriptor<ProposeSwiftData>(predicate: predicate)
        
        do {
            let models = try modelContext.fetch(descriptor)
            for model in models {
                modelContext.delete(model)
            }
            try modelContext.save()
        } catch {
            throw ProposeRepositoryError.deleteError(error)
        }
    }
}
