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

@MainActor
protocol SpaceRepository {
    func create(_ space: Space) throws
    func fetchAll() throws -> [Space]
    func fetch(by id: UUID) throws -> Space
    func update(_ space: Space) throws
    func delete(by id: UUID) throws
    func deleteAll() throws
}

/// Repository providing CRUD operations for Space using SwiftData
@MainActor
final class SpaceRepositoryImpl: SpaceRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Create
    
    /// Create a new Space
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
    
    /// Retrieve all Spaces (sorted by orderIndex)
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
    
    /// Retrieve a Space by a specific ID
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

            return SpaceConverter.toEntity(from: model)
        } catch let error as SpaceRepositoryError {
            throw error
        } catch {
            throw SpaceRepositoryError.fetchError(error)
        }
    }
    
    // MARK: - Update
    
    /// Update an existing Space
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
    /// Delete a Space by a specific ID
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
    
    /// Delete all Spaces
    func deleteAll() throws {
        do {
            try modelContext.delete(model: SpaceSwiftData.self)
            try modelContext.save()
        } catch {
            throw SpaceRepositoryError.deleteError(error)
        }
    }
}
