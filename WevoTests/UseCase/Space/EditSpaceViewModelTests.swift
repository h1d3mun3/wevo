//
//  EditSpaceViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct EditSpaceViewModelTests {

    // MARK: - Helpers

    private func makeSpace(
        id: UUID = UUID(),
        name: String = "Test Space",
        url: String = "https://example.com",
        defaultIdentityID: UUID? = nil
    ) -> Space {
        Space(
            id: id,
            name: name,
            url: url,
            defaultIdentityID: defaultIdentityID,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeViewModel(
        space: Space? = nil,
        deps: MockDependencyContainer? = nil,
        onUpdate: @escaping () -> Void = {}
    ) -> EditSpaceViewModel {
        EditSpaceViewModel(
            space: space ?? makeSpace(),
            onUpdate: onUpdate,
            deps: deps ?? MockDependencyContainer()
        )
    }

    // MARK: - canSave

    @Test func testCanSaveFalseWhenNameEmpty() {
        let space = makeSpace(name: "Original", url: "https://example.com")
        let vm = makeViewModel(space: space)
        vm.name = ""
        vm.url = "https://new.com"
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenURLEmpty() {
        let space = makeSpace(name: "Original", url: "https://example.com")
        let vm = makeViewModel(space: space)
        vm.name = "New Name"
        vm.url = ""
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenSaving() {
        let space = makeSpace(name: "Original", url: "https://example.com")
        let vm = makeViewModel(space: space)
        vm.name = "New Name"
        vm.url = "https://new.com"
        vm.isSaving = true
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenNoChanges() {
        let space = makeSpace(name: "Original", url: "https://example.com", defaultIdentityID: nil)
        let vm = makeViewModel(space: space)
        // After init: name/url equal space values, selectedIdentity is nil == defaultIdentityID nil
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveTrueWhenNameChanged() {
        let space = makeSpace(name: "Original", url: "https://example.com")
        let vm = makeViewModel(space: space)
        vm.name = "Updated"
        #expect(vm.canSave == true)
    }

    @Test func testCanSaveTrueWhenURLChanged() {
        let space = makeSpace(name: "Original", url: "https://example.com")
        let vm = makeViewModel(space: space)
        vm.url = "https://new.com"
        #expect(vm.canSave == true)
    }

    @Test func testCanSaveTrueWhenIdentityChanged() {
        let originalID = UUID()
        let space = makeSpace(defaultIdentityID: originalID)
        let vm = makeViewModel(space: space)
        vm.selectedIdentity = Identity(id: UUID(), nickname: "Other", publicKey: "key")
        #expect(vm.canSave == true)
    }

    // MARK: - loadIdentities

    @Test func testLoadIdentitiesSelectsMatchingIdentity() {
        let defaultID = UUID()
        let defaultIdentity = Identity(id: defaultID, nickname: "Default", publicKey: "defaultKey")
        let other = Identity(id: UUID(), nickname: "Other", publicKey: "otherKey")
        let space = makeSpace(defaultIdentityID: defaultID)

        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesResult = [other, defaultIdentity]

        let vm = makeViewModel(space: space, deps: deps)
        vm.loadIdentities()

        #expect(vm.identities.count == 2)
        #expect(vm.selectedIdentity?.id == defaultID)
    }

    @Test func testLoadIdentitiesSelectsNilWhenNoMatch() {
        let identity = Identity(id: UUID(), nickname: "Other", publicKey: "key")
        let space = makeSpace(defaultIdentityID: UUID())

        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesResult = [identity]

        let vm = makeViewModel(space: space, deps: deps)
        vm.loadIdentities()

        #expect(vm.identities.count == 1)
        #expect(vm.selectedIdentity == nil)
    }

    @Test func testLoadIdentitiesLeavesEmptyOnError() {
        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesError = KeychainError.invalidData

        let vm = makeViewModel(deps: deps)
        vm.loadIdentities()

        #expect(vm.identities.isEmpty)
        #expect(vm.selectedIdentity == nil)
    }

    // MARK: - saveChanges

    @Test func testSaveChangesSuccessDismisses() async {
        let space = makeSpace()
        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDResult = space

        let vm = makeViewModel(space: space, deps: deps)
        vm.name = "Updated"

        await vm.saveChanges()

        #expect(vm.shouldDismiss == true)
        #expect(vm.errorMessage == nil)
    }

    @Test func testSaveChangesSuccessCallsOnUpdate() async {
        let space = makeSpace()
        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDResult = space

        var onUpdateCalled = false
        let vm = makeViewModel(space: space, deps: deps, onUpdate: { onUpdateCalled = true })
        vm.name = "Updated"

        await vm.saveChanges()

        #expect(onUpdateCalled == true)
    }

    @Test func testSaveChangesFailureSetsErrorMessage() async {
        let space = makeSpace()
        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchByIDError = NSError(domain: "test", code: -1)

        let vm = makeViewModel(space: space, deps: deps)
        vm.name = "Updated"

        await vm.saveChanges()

        #expect(vm.errorMessage != nil)
        #expect(vm.shouldDismiss == false)
    }
}
