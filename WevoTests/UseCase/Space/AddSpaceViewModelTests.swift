//
//  AddSpaceViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct AddSpaceViewModelTests {

    private func makeViewModel(deps: MockDependencyContainer? = nil) -> AddSpaceViewModel {
        AddSpaceViewModel(deps: deps ?? MockDependencyContainer())
    }

    // MARK: - canSave

    @Test func testCanSaveFalseWhenNameEmpty() {
        let vm = makeViewModel()
        vm.name = ""
        vm.urlString = "https://example.com"
        vm.selectedIdentityID = UUID()
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenURLEmpty() {
        let vm = makeViewModel()
        vm.name = "My Space"
        vm.urlString = ""
        vm.selectedIdentityID = UUID()
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenNoIdentity() {
        let vm = makeViewModel()
        vm.name = "My Space"
        vm.urlString = "https://example.com"
        vm.selectedIdentityID = nil
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveFalseWhenSaving() {
        let vm = makeViewModel()
        vm.name = "My Space"
        vm.urlString = "https://example.com"
        vm.selectedIdentityID = UUID()
        vm.isSaving = true
        #expect(vm.canSave == false)
    }

    @Test func testCanSaveTrueWhenAllSet() {
        let vm = makeViewModel()
        vm.name = "My Space"
        vm.urlString = "https://example.com"
        vm.selectedIdentityID = UUID()
        #expect(vm.canSave == true)
    }

    // MARK: - loadIdentities

    @Test func testLoadIdentitiesPopulatesAndSelectsDefault() async {
        let defaultID = UUID()
        let identity = Identity(id: defaultID, nickname: "Default", publicKey: "key")

        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesResult = [identity]

        let vm = makeViewModel(deps: deps)
        await vm.loadIdentities()

        #expect(vm.identities.count == 1)
        #expect(vm.selectedIdentityID == defaultID)
    }

    @Test func testLoadIdentitiesLeavesEmptyOnError() async {
        let deps = MockDependencyContainer()
        (deps.keychainRepository as! MockKeychainRepository).getAllIdentitiesError = KeychainError.invalidData

        let vm = makeViewModel(deps: deps)
        await vm.loadIdentities()

        #expect(vm.identities.isEmpty)
    }
}
