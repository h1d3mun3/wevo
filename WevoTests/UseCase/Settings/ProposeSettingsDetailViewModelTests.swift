//
//  ProposeSettingsDetailViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ProposeSettingsDetailViewModelTests {

    // MARK: - Helpers

    private func makePropose(
        counterpartySignTimestamp: String? = nil,
        creatorHonorTimestamp: String? = nil,
        counterpartyHonorTimestamp: String? = nil,
        creatorPartTimestamp: String? = nil,
        counterpartyPartTimestamp: String? = nil,
        creatorDissolveTimestamp: String? = nil,
        counterpartyDissolveTimestamp: String? = nil
    ) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: "creatorPubKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyPubKey",
            counterpartySignTimestamp: counterpartySignTimestamp,
            counterpartyHonorTimestamp: counterpartyHonorTimestamp,
            counterpartyPartTimestamp: counterpartyPartTimestamp,
            creatorHonorTimestamp: creatorHonorTimestamp,
            creatorPartTimestamp: creatorPartTimestamp,
            creatorDissolveTimestamp: creatorDissolveTimestamp,
            counterpartyDissolveTimestamp: counterpartyDissolveTimestamp,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private func makeViewModel(
        propose: Propose? = nil,
        deps: MockDependencyContainer? = nil
    ) -> ProposeSettingsDetailViewModel {
        ProposeSettingsDetailViewModel(
            propose: propose ?? makePropose(),
            deps: deps ?? MockDependencyContainer()
        )
    }

    // MARK: - hasEventTimestamps

    @Test func testHasEventTimestampsFalseWhenAllNil() {
        let vm = makeViewModel(propose: makePropose())
        #expect(vm.hasEventTimestamps == false)
    }

    @Test func testHasEventTimestampsTrueWhenCounterpartySignTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(counterpartySignTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    @Test func testHasEventTimestampsTrueWhenCreatorHonorTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(creatorHonorTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    @Test func testHasEventTimestampsTrueWhenCounterpartyHonorTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(counterpartyHonorTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    @Test func testHasEventTimestampsTrueWhenCreatorPartTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(creatorPartTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    @Test func testHasEventTimestampsTrueWhenCounterpartyPartTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(counterpartyPartTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    @Test func testHasEventTimestampsTrueWhenCreatorDissolveTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(creatorDissolveTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    @Test func testHasEventTimestampsTrueWhenCounterpartyDissolveTimestampPresent() {
        let vm = makeViewModel(propose: makePropose(counterpartyDissolveTimestamp: "2026-01-01T00:00:00Z"))
        #expect(vm.hasEventTimestamps == true)
    }

    // MARK: - nickname(for:)

    @Test func testNicknameReturnsContactNicknameWhenPresent() {
        let vm = makeViewModel()
        vm.contactNicknames = ["somePubKey": "Alice"]
        #expect(vm.nickname(for: "somePubKey") == "Alice")
    }

    @Test func testNicknameFallsBackToTruncatedKeyWhenAbsent() {
        let vm = makeViewModel()
        vm.contactNicknames = [:]
        #expect(vm.nickname(for: "abcdefghijklmnopqrstuvwxyz") == "abcdefghijklmnop...")
    }

    @Test func testNicknameFallsBackWhenKeyTooShort() {
        let vm = makeViewModel()
        vm.contactNicknames = [:]
        #expect(vm.nickname(for: "short") == "short...")
    }

    // MARK: - loadContactNicknames

    @Test func testLoadContactNicknamesBuildsMappingOnSuccess() async {
        let contacts = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "aliceKey", createdAt: .now),
            Contact(id: UUID(), nickname: "Bob", publicKey: "bobKey", createdAt: .now)
        ]
        let deps = MockDependencyContainer()
        (deps.contactRepository as! MockContactRepository).fetchAllResult = contacts

        let vm = makeViewModel(deps: deps)
        await vm.load()

        #expect(vm.contactNicknames["aliceKey"] == "Alice")
        #expect(vm.contactNicknames["bobKey"] == "Bob")
    }

    @Test func testLoadContactNicknamesRemainsEmptyOnError() async {
        let deps = MockDependencyContainer()
        (deps.contactRepository as! MockContactRepository).fetchAllError = ContactRepositoryError.fetchError(
            NSError(domain: "test", code: 0)
        )

        let vm = makeViewModel(deps: deps)
        await vm.load()

        #expect(vm.contactNicknames.isEmpty)
    }
}
