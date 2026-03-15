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

/// Repository providing CRUD operations for Propose using SwiftData
final class ProposeRepositoryImpl: ProposeRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Create
    
    /// Create a new Propose
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

    /// Retrieve all Proposes (sorted by creation date descending)
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

    /// Retrieve all Proposes belonging to a specific Space (sorted by creation date descending)
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

    /// Retrieve Proposes whose SpaceID is not in the valid set (sorted by creation date descending)
    func fetchAllOrphaned(validSpaceIDs: Set<UUID>) throws -> [Propose] {
        let descriptor = FetchDescriptor<ProposeSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            let orphaned = models.filter { !validSpaceIDs.contains($0.spaceID) }
            return ProposeConverter.toEntities(from: orphaned)
        } catch {
            throw ProposeRepositoryError.fetchError(error)
        }
    }
    
    /// Retrieve a Propose by a specific ID
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
        } catch let error as ProposeRepositoryError {
            throw error
        } catch {
            throw ProposeRepositoryError.fetchError(error)
        }
    }
    
    // MARK: - Update
    
    /// Update an existing Propose
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
    
    /// Delete a Propose by a specific ID
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
    
    /// Delete all Proposes belonging to a specific Space
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
