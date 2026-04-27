//
//  CreateProposeViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct CreateProposeViewModelTests {

    // MARK: - Helpers

    private func makeSpace(defaultIdentityID: UUID? = nil) -> Space {
        Space(
            id: UUID(),
            name: "Test Space",
            url: "https://example.com",
            defaultIdentityID: defaultIdentityID,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeViewModel(
        space: Space? = nil,
        deps: MockDependencyContainer? = nil,
        onSuccess: @escaping () -> Void = {}
    ) -> CreateProposeViewModel {
        CreateProposeViewModel(
            space: space ?? makeSpace(),
            onSuccess: onSuccess,
            deps: deps ?? MockDependencyContainer()
        )
    }

    // MARK: - canSave

    @Test func testCanSaveFalseWhenMessageEmpty() {
        let vm = makeViewModel()
        vm.message = ""
        vm.selectedContact = Contact(id: UUID(), nickname: "Alice", publicKey: "aliceKey", createdAt: .now)
        vm.selectedIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenNoContact() {
        let vm = makeViewModel()
        vm.message = "hello"
        vm.selectedContact = nil
        vm.selectedIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenNoIdentity() {
        let vm = makeViewModel()
        vm.message = "hello"
        vm.selectedContact = Contact(id: UUID(), nickname: "Alice", publicKey: "aliceKey", createdAt: .now)
        vm.selectedIdentity = nil
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenSaving() {
        let vm = makeViewModel()
        vm.message = "hello"
        vm.selectedContact = Contact(id: UUID(), nickname: "Alice", publicKey: "aliceKey", createdAt: .now)
        vm.selectedIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        vm.isSaving = true
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveTrueWhenAllSet() {
        let vm = makeViewModel()
        vm.message = "hello"
        vm.selectedContact = Contact(id: UUID(), nickname: "Alice", publicKey: "aliceKey", createdAt: .now)
        vm.selectedIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.canSave == true)
    }

    // MARK: - loadIdentities

    @Test func testLoadIdentitiesSelectsDefaultIdentity() {
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

    @Test func testLoadIdentitiesFallsBackToFirstWhenNoDefault() {
        let first = Identity(id: UUID(), nickname: "First", publicKey: "firstKey")
        let second = Identity(id: UUID(), nickname: "Second", publicKey: "secondKey")

        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesResult = [first, second]

        let vm = makeViewModel(deps: deps)
        vm.loadIdentities()

        #expect(vm.selectedIdentity?.id == first.id)
    }

    @Test func testLoadIdentitiesLeavesIdentitiesEmptyOnError() {
        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesError = KeychainError.invalidData

        let vm = makeViewModel(deps: deps)
        vm.loadIdentities()

        #expect(vm.identities.isEmpty)
        #expect(vm.selectedIdentity == nil)
    }
}
