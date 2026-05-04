//
//  ContentViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ContentViewModelTests {

    // MARK: - Helpers

    private func makeSpace(id: UUID = UUID()) -> Space {
        Space(
            id: id,
            name: "Test Space",
            url: "https://example.com",
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makePropose(spaceID: UUID = UUID()) -> Propose {
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: "test message",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeViewModel(deps: MockDependencyContainer? = nil) -> ContentViewModel {
        ContentViewModel(deps: deps ?? MockDependencyContainer())
    }

    // MARK: - loadSpaces

    @Test func testLoadSpacesPopulatesSpaces() async {
        let space = makeSpace()
        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchAllResult = [space]

        let vm = makeViewModel(deps: deps)
        await vm.loadSpaces()

        #expect(vm.spaces.count == 1)
        #expect(vm.spaces[0].id == space.id)
    }

    @Test func testLoadSpacesPopulatesOrphanedGroups() async {
        let orphanSpaceID = UUID()
        let propose = makePropose(spaceID: orphanSpaceID)

        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchAllResult = []
        (deps.proposeRepository as! MockProposeRepository).fetchAllOrphanedResult = [propose]

        let vm = makeViewModel(deps: deps)
        await vm.loadSpaces()

        #expect(vm.orphanedProposeGroups.count == 1)
        #expect(vm.orphanedProposeGroups[0].spaceID == orphanSpaceID)
    }

    @Test func testLoadSpacesFiltersOrphanedByValidSpaceIDs() async {
        let validSpace = makeSpace()
        let ownedPropose = makePropose(spaceID: validSpace.id)
        let orphanPropose = makePropose(spaceID: UUID())

        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchAllResult = [validSpace]
        (deps.proposeRepository as! MockProposeRepository).fetchAllOrphanedResult = [orphanPropose]

        let vm = makeViewModel(deps: deps)
        await vm.loadSpaces()

        #expect(vm.spaces.count == 1)
        #expect(vm.orphanedProposeGroups.count == 1)
        let passedIDs = (deps.proposeRepository as! MockProposeRepository).fetchAllOrphanedValidSpaceIDs
        #expect(passedIDs?.contains(validSpace.id) == true)
        #expect(passedIDs?.contains(ownedPropose.spaceID) == true)
    }

    @Test func testLoadSpacesClearsOnError() async {
        let deps = MockDependencyContainer()
        (deps.spaceRepository as! MockSpaceRepository).fetchAllError = NSError(domain: "test", code: -1)

        let vm = makeViewModel(deps: deps)
        vm.spaces = [makeSpace()]
        await vm.loadSpaces()

        #expect(vm.spaces.isEmpty)
        #expect(vm.orphanedProposeGroups.isEmpty)
    }

    // MARK: - deleteSpace

    @Test func testDeleteSpaceCallsDelete() async {
        let space = makeSpace()
        let deps = MockDependencyContainer()
        let mockSpaceRepo = deps.spaceRepository as! MockSpaceRepository
        mockSpaceRepo.fetchAllResult = [space]

        let vm = makeViewModel(deps: deps)
        vm.spaces = [space]

        vm.deleteSpace(offsets: IndexSet(integer: 0))
        // Yield to allow the internal Task to execute
        await Task.yield()
        await Task.yield()

        #expect(mockSpaceRepo.deleteCalled == true)
        #expect(mockSpaceRepo.deletedID == space.id)
    }

    @Test func testDeleteSpaceReloadsSpaces() async {
        let space = makeSpace()
        let deps = MockDependencyContainer()
        let mockSpaceRepo = deps.spaceRepository as! MockSpaceRepository
        mockSpaceRepo.fetchAllResult = []

        let vm = makeViewModel(deps: deps)
        vm.spaces = [space]

        vm.deleteSpace(offsets: IndexSet(integer: 0))
        await Task.yield()
        await Task.yield()

        #expect(vm.spaces.isEmpty)
    }
}
