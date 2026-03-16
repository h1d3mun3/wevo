//
//  DependencyContainer.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI
import SwiftData

// MARK: - Protocol

@MainActor
protocol DependencyContainer {
    var keychainRepository: KeychainRepository { get }
    var spaceRepository: SpaceRepository { get }
    var proposeRepository: ProposeRepository { get }
    var contactRepository: ContactRepository { get }
}

// MARK: - App Implementation

@MainActor
final class AppDependencyContainer: DependencyContainer {
    private let modelContext: ModelContext

    private(set) lazy var keychainRepository: KeychainRepository = KeychainRepositoryImpl()
    private(set) lazy var spaceRepository: SpaceRepository = SpaceRepositoryImpl(modelContext: modelContext)
    private(set) lazy var proposeRepository: ProposeRepository = ProposeRepositoryImpl(modelContext: modelContext)
    private(set) lazy var contactRepository: ContactRepository = ContactRepositoryImpl(modelContext: modelContext)

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}

// MARK: - SwiftUI Environment

private struct DependencyContainerKey: EnvironmentKey {
    @MainActor static let defaultValue: any DependencyContainer = PlaceholderDependencyContainer()
}

extension EnvironmentValues {
    var dependencies: any DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - Placeholder (crashes if used without proper setup)

@MainActor
private final class PlaceholderDependencyContainer: DependencyContainer {
    var keychainRepository: KeychainRepository {
        fatalError("DependencyContainer not configured. Set .environment(\\.dependencies, ...) in WevoApp.")
    }
    var spaceRepository: SpaceRepository {
        fatalError("DependencyContainer not configured. Set .environment(\\.dependencies, ...) in WevoApp.")
    }
    var proposeRepository: ProposeRepository {
        fatalError("DependencyContainer not configured. Set .environment(\\.dependencies, ...) in WevoApp.")
    }
    var contactRepository: ContactRepository {
        fatalError("DependencyContainer not configured. Set .environment(\\.dependencies, ...) in WevoApp.")
    }
}
