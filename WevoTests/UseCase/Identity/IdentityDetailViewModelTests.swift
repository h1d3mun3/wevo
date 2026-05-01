//
//  IdentityDetailViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct IdentityDetailViewModelTests {

    // MARK: - Helpers

    private func makeIdentity(publicKey: String = "testPublicKey") -> Identity {
        Identity(id: UUID(), nickname: "Test Identity", publicKey: publicKey)
    }

    private func makeViewModel(
        identity: Identity? = nil,
        deps: MockDependencyContainer? = nil
    ) -> IdentityDetailViewModel {
        IdentityDetailViewModel(
            identity: identity ?? makeIdentity(),
            deps: deps ?? MockDependencyContainer()
        )
    }

    // MARK: - Initial State

    @Test func testInitialState() {
        let vm = makeViewModel()

        #expect(vm.shareURL == nil)
        #expect(vm.exportError == nil)
        #expect(vm.isAuthenticating == false)
        #expect(vm.contactShareURL == nil)
        #expect(vm.contactExportError == nil)
        #expect(vm.showingEditSheet == false)
    }

    // MARK: - authenticateAndExport

    @Test func testAuthenticateAndExportSetsShareURLOnSuccess() async {
        let expectedURL = URL(fileURLWithPath: "/tmp/test.wevo-identity")
        let deps = MockDependencyContainer()
        let mock = deps.authenticateAndExportIdentityUseCase as! MockAuthenticateAndExportIdentityUseCase
        mock.executeResult = expectedURL

        let vm = makeViewModel(deps: deps)
        await vm.authenticateAndExport()

        #expect(vm.shareURL == expectedURL)
        #expect(vm.exportError == nil)
    }

    @Test func testAuthenticateAndExportSetsErrorOnFailure() async {
        let deps = MockDependencyContainer()
        let mock = deps.authenticateAndExportIdentityUseCase as! MockAuthenticateAndExportIdentityUseCase
        mock.executeError = AuthenticateAndExportIdentityUseCaseError.authenticationFailed

        let vm = makeViewModel(deps: deps)
        await vm.authenticateAndExport()

        #expect(vm.shareURL == nil)
        #expect(vm.exportError != nil)
    }

    @Test func testAuthenticateAndExportResetsIsAuthenticatingAfterSuccess() async {
        let vm = makeViewModel()
        await vm.authenticateAndExport()

        #expect(vm.isAuthenticating == false)
    }

    @Test func testAuthenticateAndExportResetsIsAuthenticatingAfterFailure() async {
        let deps = MockDependencyContainer()
        let mock = deps.authenticateAndExportIdentityUseCase as! MockAuthenticateAndExportIdentityUseCase
        mock.executeError = AuthenticateAndExportIdentityUseCaseError.authenticationFailed

        let vm = makeViewModel(deps: deps)
        await vm.authenticateAndExport()

        #expect(vm.isAuthenticating == false)
    }

    @Test func testAuthenticateAndExportPassesCorrectIdentity() async {
        let identity = makeIdentity(publicKey: "specificKey")
        let deps = MockDependencyContainer()
        let mock = deps.authenticateAndExportIdentityUseCase as! MockAuthenticateAndExportIdentityUseCase

        let vm = makeViewModel(identity: identity, deps: deps)
        await vm.authenticateAndExport()

        #expect(mock.executeCalledWithIdentity?.publicKey == "specificKey")
    }

    // MARK: - prepareContactExport

    @Test func testPrepareContactExportSetsContactShareURLOnSuccess() {
        let expectedURL = URL(fileURLWithPath: "/tmp/contact.wevo-contact")
        let deps = MockDependencyContainer()
        let mock = deps.exportIdentityAsContactUseCase as! MockExportIdentityAsContactUseCase
        mock.executeResult = expectedURL

        let vm = makeViewModel(deps: deps)
        vm.prepareContactExport()

        #expect(vm.contactShareURL == expectedURL)
        #expect(vm.contactExportError == nil)
    }

    @Test func testPrepareContactExportSetsErrorOnFailure() {
        let deps = MockDependencyContainer()
        let mock = deps.exportIdentityAsContactUseCase as! MockExportIdentityAsContactUseCase
        mock.executeError = NSError(domain: "test", code: 1)

        let vm = makeViewModel(deps: deps)
        vm.prepareContactExport()

        #expect(vm.contactShareURL == nil)
        #expect(vm.contactExportError != nil)
    }

    @Test func testPrepareContactExportIsIdempotentWhenURLAlreadySet() {
        let firstURL = URL(fileURLWithPath: "/tmp/first.wevo-contact")
        let secondURL = URL(fileURLWithPath: "/tmp/second.wevo-contact")
        let deps = MockDependencyContainer()
        let mock = deps.exportIdentityAsContactUseCase as! MockExportIdentityAsContactUseCase
        mock.executeResult = firstURL

        let vm = makeViewModel(deps: deps)
        vm.prepareContactExport()

        mock.executeResult = secondURL
        vm.prepareContactExport()

        // URL remains from first call; use case called only once due to guard
        #expect(vm.contactShareURL == firstURL)
        #expect(mock.executeCallCount == 1)
    }

    // MARK: - cleanupExportFile

    @Test func testCleanupExportFileClearsShareURL() async {
        let deps = MockDependencyContainer()
        let vm = makeViewModel(deps: deps)

        await vm.authenticateAndExport()
        vm.cleanupExportFile()

        #expect(vm.shareURL == nil)
    }

    @Test func testCleanupExportFileClearsContactShareURL() {
        let deps = MockDependencyContainer()
        let vm = makeViewModel(deps: deps)

        vm.prepareContactExport()
        vm.cleanupExportFile()

        #expect(vm.contactShareURL == nil)
    }

    @Test func testCleanupExportFileCallsUseCase() {
        let deps = MockDependencyContainer()
        let mock = deps.cleanupExportFileUseCase as! MockCleanupExportFileUseCase

        let vm = makeViewModel(deps: deps)
        vm.cleanupExportFile()

        #expect(mock.executeCalled == true)
    }

    @Test func testCleanupExportFilePassesBothURLsToUseCase() async {
        let shareURL = URL(fileURLWithPath: "/tmp/identity.wevo-identity")
        let contactURL = URL(fileURLWithPath: "/tmp/contact.wevo-contact")

        let deps = MockDependencyContainer()
        let authMock = deps.authenticateAndExportIdentityUseCase as! MockAuthenticateAndExportIdentityUseCase
        authMock.executeResult = shareURL
        let contactMock = deps.exportIdentityAsContactUseCase as! MockExportIdentityAsContactUseCase
        contactMock.executeResult = contactURL
        let cleanupMock = deps.cleanupExportFileUseCase as! MockCleanupExportFileUseCase

        let vm = makeViewModel(deps: deps)
        await vm.authenticateAndExport()
        vm.prepareContactExport()
        vm.cleanupExportFile()

        #expect(cleanupMock.executeCalledWithURLs.contains(shareURL))
        #expect(cleanupMock.executeCalledWithURLs.contains(contactURL))
    }
}
