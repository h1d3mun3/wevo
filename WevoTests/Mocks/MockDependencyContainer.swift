//
//  MockDependencyContainer.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Foundation
@testable import Wevo

// MARK: - Mock Use Cases

class MockAuthenticateAndExportIdentityUseCase: AuthenticateAndExportIdentityUseCase {
    var executeResult: URL = URL(fileURLWithPath: "/tmp/identity.wevo-identity")
    var executeError: Error?
    var executeCalled = false
    var executeCalledWithIdentity: Identity?

    func execute(identity: Identity) async throws -> URL {
        executeCalled = true
        executeCalledWithIdentity = identity
        if let error = executeError { throw error }
        return executeResult
    }
}

class MockExportIdentityAsContactUseCase: ExportIdentityAsContactUseCase {
    var executeResult: URL = URL(fileURLWithPath: "/tmp/contact.wevo-contact")
    var executeError: Error?
    var executeCallCount = 0
    var executeCalledWithIdentity: Identity?

    func execute(identity: Identity) throws -> URL {
        executeCallCount += 1
        executeCalledWithIdentity = identity
        if let error = executeError { throw error }
        return executeResult
    }
}

class MockCleanupExportFileUseCase: CleanupExportFileUseCase {
    var executeCalled = false
    var executeCalledWithURLs: [URL?] = []

    func execute(urls: [URL?]) {
        executeCalled = true
        executeCalledWithURLs = urls
    }
}

// MARK: - Mock Container

@MainActor
class MockDependencyContainer: DependencyContainer {
    var keychainRepository: KeychainRepository = MockKeychainRepository()
    var spaceRepository: SpaceRepository = MockSpaceRepository()
    var proposeRepository: ProposeRepository = MockProposeRepository()
    var contactRepository: ContactRepository = MockContactRepository()
    var authenticateAndExportIdentityUseCase: any AuthenticateAndExportIdentityUseCase = MockAuthenticateAndExportIdentityUseCase()
    var exportIdentityAsContactUseCase: any ExportIdentityAsContactUseCase = MockExportIdentityAsContactUseCase()
    var cleanupExportFileUseCase: any CleanupExportFileUseCase = MockCleanupExportFileUseCase()
}
