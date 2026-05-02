//
//  IdentityDetailViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class IdentityDetailViewModel {
    var errorMessage: String?
    var exportError: String?
    var showingEditSheet = false
    var shareURL: URL?
    var isAuthenticating = false
    var contactShareURL: URL?
    var contactExportError: String?

    let identity: Identity
    private let deps: any DependencyContainer

    init(identity: Identity, deps: any DependencyContainer) {
        self.identity = identity
        self.deps = deps
    }

    func authenticateAndExport() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            shareURL = try await deps.authenticateAndExportIdentityUseCase.execute(identity: identity)
            exportError = nil
        } catch {
            exportError = "Failed to export identity: \(error.localizedDescription)"
        }
    }

    func prepareContactExport() {
        guard contactShareURL == nil else { return }
        do {
            contactShareURL = try deps.exportIdentityAsContactUseCase.execute(identity: identity)
            contactExportError = nil
        } catch {
            contactExportError = "Failed to export: \(error.localizedDescription)"
        }
    }

    func cleanupExportFile() {
        deps.cleanupExportFileUseCase.execute(urls: [shareURL, contactShareURL])
        shareURL = nil
        contactShareURL = nil
    }
}
