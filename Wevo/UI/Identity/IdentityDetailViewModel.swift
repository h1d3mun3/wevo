//
//  IdentityDetailViewModel.swift
//  Wevo
//

<<<<<<< HEAD
import Foundation
=======
import SwiftUI
import os
>>>>>>> rc-1.1.0

@Observable
@MainActor
final class IdentityDetailViewModel {
<<<<<<< HEAD
    let identity: Identity
    private let deps: any DependencyContainer

    var shareURL: URL?
    var exportError: String?
    var isAuthenticating = false
    var contactShareURL: URL?
    var contactExportError: String?
    var showingEditSheet = false
=======
    var errorMessage: String?
    var exportError: String?
    var showingEditSheet = false
    var shareURL: URL?
    var isAuthenticating = false
    var contactShareURL: URL?
    var contactExportError: String?

    let identity: Identity
    private let deps: any DependencyContainer
>>>>>>> rc-1.1.0

    init(identity: Identity, deps: any DependencyContainer) {
        self.identity = identity
        self.deps = deps
    }

    func authenticateAndExport() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
<<<<<<< HEAD
        do {
            shareURL = try await deps.authenticateAndExportIdentityUseCase.execute(identity: identity)
            exportError = nil
=======
        let useCase = AuthenticateAndExportIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            shareURL = try await useCase.execute(identity: identity)
>>>>>>> rc-1.1.0
        } catch {
            exportError = "Failed to export identity: \(error.localizedDescription)"
        }
    }

    func prepareContactExport() {
        guard contactShareURL == nil else { return }
<<<<<<< HEAD
        do {
            contactShareURL = try deps.exportIdentityAsContactUseCase.execute(identity: identity)
            contactExportError = nil
=======
        let useCase = ExportIdentityAsContactUseCaseImpl()
        do {
            contactShareURL = try useCase.execute(identity: identity)
>>>>>>> rc-1.1.0
        } catch {
            contactExportError = "Failed to export: \(error.localizedDescription)"
        }
    }

    func cleanupExportFile() {
<<<<<<< HEAD
        deps.cleanupExportFileUseCase.execute(urls: [shareURL, contactShareURL])
=======
        let useCase = CleanupExportFileUseCaseImpl()
        useCase.execute(urls: [shareURL, contactShareURL])
>>>>>>> rc-1.1.0
        shareURL = nil
        contactShareURL = nil
    }
}
