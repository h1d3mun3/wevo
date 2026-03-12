//
//  ContactRepository.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation
import SwiftData

enum ContactRepositoryError: Error {
    case contactNotFound(UUID)
    case saveError(Error)
    case deleteError(Error)
    case fetchError(Error)
}

@MainActor
protocol ContactRepository {
    func create(_ contact: Contact) throws
    func fetchAll() throws -> [Contact]
    func fetch(by id: UUID) throws -> Contact
    func update(_ contact: Contact) throws
    func delete(by id: UUID) throws
}

/// SwiftDataを使用してContactのCRUD操作を提供するRepository
@MainActor
final class ContactRepositoryImpl: ContactRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    func create(_ contact: Contact) throws {
        let model = ContactConverter.toModel(from: contact)
        modelContext.insert(model)

        do {
            try modelContext.save()
        } catch {
            throw ContactRepositoryError.saveError(error)
        }
    }

    // MARK: - Read

    /// すべてのContactを取得（作成日時の昇順）
    func fetchAll() throws -> [Contact] {
        let descriptor = FetchDescriptor<ContactSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let models = try modelContext.fetch(descriptor)
            return ContactConverter.toEntities(from: models)
        } catch {
            throw ContactRepositoryError.fetchError(error)
        }
    }

    func fetch(by id: UUID) throws -> Contact {
        let predicate = #Predicate<ContactSwiftData> { model in
            model.id == id
        }

        var descriptor = FetchDescriptor<ContactSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw ContactRepositoryError.contactNotFound(id)
            }
            return ContactConverter.toEntity(from: model)
        } catch {
            throw ContactRepositoryError.fetchError(error)
        }
    }

    // MARK: - Update

    func update(_ contact: Contact) throws {
        let contactID = contact.id
        let predicate = #Predicate<ContactSwiftData> { model in
            model.id == contactID
        }

        var descriptor = FetchDescriptor<ContactSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw ContactRepositoryError.contactNotFound(contact.id)
            }

            ContactConverter.updateModel(model, with: contact)
            try modelContext.save()
        } catch let error as ContactRepositoryError {
            throw error
        } catch {
            throw ContactRepositoryError.saveError(error)
        }
    }

    // MARK: - Delete

    func delete(by id: UUID) throws {
        let predicate = #Predicate<ContactSwiftData> { model in
            model.id == id
        }

        var descriptor = FetchDescriptor<ContactSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let models = try modelContext.fetch(descriptor)
            guard let model = models.first else {
                throw ContactRepositoryError.contactNotFound(id)
            }

            modelContext.delete(model)
            try modelContext.save()
        } catch let error as ContactRepositoryError {
            throw error
        } catch {
            throw ContactRepositoryError.deleteError(error)
        }
    }
}
