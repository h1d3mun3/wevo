//
//  SpaceDetailViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct SpaceDetailViewModelTests {

    // MARK: - Helpers

    private func makeSpace(id: UUID = UUID(), name: String = "Test Space", defaultIdentityID: UUID? = nil) -> Space {
        Space(
            id: id,
            name: name,
            url: "https://example.com",
            defaultIdentityID: defaultIdentityID,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makePropose(
        spaceID: UUID = UUID(),
        counterpartySignSignature: String? = nil,
        counterpartyDissolveSignature: String? = nil
    ) -> Propose {
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: "test message",
            creatorPublicKey: "creatorPubKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyPubKey",
            counterpartySignSignature: counterpartySignSignature,
            counterpartyDissolveSignature: counterpartyDissolveSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeViewModel(
        space: Space? = nil,
        deps: MockDependencyContainer? = nil
    ) -> SpaceDetailViewModel {
        SpaceDetailViewModel(
            space: space ?? makeSpace(),
            deps: deps ?? MockDependencyContainer()
        )
    }

    // MARK: - Initial State

    @Test func testInitialState() {
        let space = makeSpace()
        let vm = makeViewModel(space: space)

        #expect(vm.proposes.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.defaultIdentity == nil)
        #expect(vm.selectedTab == .active)
        #expect(vm.currentSpace.id == space.id)
        #expect(vm.shouldShowCreatePropose == false)
        #expect(vm.shouldShowEditSpace == false)
        #expect(vm.shouldDismiss == false)
    }

    // MARK: - activeProposes / completedProposes

    @Test func testActiveProposesFiltersCorrectly() {
        let vm = makeViewModel()
        let proposed = makePropose()
        let signed = makePropose(counterpartySignSignature: "sig")
        let dissolved = makePropose(counterpartyDissolveSignature: "dissolveSig")
        vm.proposes = [proposed, signed, dissolved]

        #expect(vm.activeProposes.count == 2)
        #expect(vm.completedProposes.count == 1)
    }

    @Test func testActiveProposesEmptyWhenNoProposesLoaded() {
        let vm = makeViewModel()

        #expect(vm.activeProposes.isEmpty)
        #expect(vm.completedProposes.isEmpty)
    }

    // MARK: - loadDefaultIdentity

    @Test func testLoadDefaultIdentitySetsIdentityOnSuccess() async {
        let identityID = UUID()
        let identity = Identity(id: identityID, nickname: "Alice", publicKey: "aliceKey")
        let space = makeSpace(defaultIdentityID: identityID)

        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesResult = [identity]

        let vm = makeViewModel(space: space, deps: deps)
        await vm.loadDefaultIdentity()

        #expect(vm.defaultIdentity?.id == identityID)
        #expect(vm.defaultIdentity?.nickname == "Alice")
    }

    @Test func testLoadDefaultIdentitySetsNilOnError() async {
        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesError = KeychainError.invalidData

        let vm = makeViewModel(deps: deps)
        await vm.loadDefaultIdentity()

        #expect(vm.defaultIdentity == nil)
    }

    // MARK: - loadProposesFromLocal

    @Test func testLoadProposesFromLocalSetsProposesOnSuccess() {
        let space = makeSpace()
        let propose = makePropose(spaceID: space.id)

        let deps = MockDependencyContainer()
        (deps.proposeRepository as! MockProposeRepository).fetchAllResult = [propose]

        let vm = makeViewModel(space: space, deps: deps)
        vm.loadProposesFromLocal()

        #expect(vm.proposes.count == 1)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func testLoadProposesFromLocalHandlesEmptyResult() {
        let deps = MockDependencyContainer()
        (deps.proposeRepository as! MockProposeRepository).fetchAllResult = []

        let vm = makeViewModel(deps: deps)
        vm.loadProposesFromLocal()

        #expect(vm.proposes.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func testLoadProposesFromLocalSetsErrorMessageOnFailure() {
        let deps = MockDependencyContainer()
        (deps.proposeRepository as! MockProposeRepository).fetchAllError = NSError(
            domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "DB error"]
        )

        let vm = makeViewModel(deps: deps)
        vm.loadProposesFromLocal()

        #expect(vm.proposes.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - reloadSpace

    @Test func testReloadSpaceUpdatesCurrentSpace() async {
        let space = makeSpace()
        let updatedSpace = makeSpace(id: space.id, name: "Updated Space")

        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDResult = updatedSpace

        let vm = makeViewModel(space: space, deps: deps)
        await vm.reloadSpace()

        #expect(vm.currentSpace.name == "Updated Space")
        #expect(vm.shouldDismiss == false)
    }

    @Test func testReloadSpaceSetsShouldDismissWhenSpaceNotFound() async {
        let space = makeSpace()

        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDError = SpaceRepositoryError.spaceNotFound(space.id)

        let vm = makeViewModel(space: space, deps: deps)
        await vm.reloadSpace()

        #expect(vm.shouldDismiss == true)
    }

    @Test func testReloadSpaceDoesNotDismissOnOtherError() async {
        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDError = NSError(domain: "test", code: 0)

        let vm = makeViewModel(deps: deps)
        await vm.reloadSpace()

        #expect(vm.shouldDismiss == false)
    }

    @Test func testReloadSpaceAlsoLoadsDefaultIdentity() async {
        let identityID = UUID()
        let identity = Identity(id: identityID, nickname: "Bob", publicKey: "bobKey")
        let space = makeSpace(defaultIdentityID: identityID)
        let updatedSpace = makeSpace(id: space.id, defaultIdentityID: identityID)

        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDResult = updatedSpace
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesResult = [identity]

        let vm = makeViewModel(space: space, deps: deps)
        await vm.reloadSpace()

        #expect(vm.defaultIdentity?.id == identityID)
    }

    // MARK: - refresh

    @Test func testRefreshLoadsProposesAndUpdatesServerCheckTrigger() {
        let space = makeSpace()
        let propose = makePropose(spaceID: space.id)

        let deps = MockDependencyContainer()
        (deps.proposeRepository as! MockProposeRepository).fetchAllResult = [propose]

        let vm = makeViewModel(space: space, deps: deps)
        let triggerBefore = vm.serverCheckTrigger
        vm.refresh()

        #expect(vm.proposes.count == 1)
        #expect(vm.serverCheckTrigger != triggerBefore)
    }
}
