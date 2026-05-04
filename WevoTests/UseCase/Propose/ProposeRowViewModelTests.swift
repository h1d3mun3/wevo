//
//  ProposeRowViewModelTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ProposeRowViewModelTests {

    // MARK: - Helpers

    private func makePropose(
        creatorPublicKey: String = "creatorPubKey",
        counterpartyPublicKey: String = "counterpartyPubKey",
        counterpartySignSignature: String? = nil
    ) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

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

    private func makeHashedPropose(for propose: Propose) -> HashedPropose {
        HashedPropose(
            id: propose.id,
            contentHash: propose.payloadHash,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterparties: [ProposeCounterparty(publicKey: propose.counterpartyPublicKey)],
            status: .proposed,
            createdAt: propose.createdAt,
            updatedAt: propose.updatedAt
        )
    }

    private func makeViewModel(
        propose: Propose? = nil,
        space: Space? = nil,
        deps: MockDependencyContainer? = nil
    ) -> ProposeRowViewModel {
        ProposeRowViewModel(
            propose: propose ?? makePropose(),
            space: space ?? makeSpace(),
            deps: deps ?? MockDependencyContainer()
        )
    }

    // MARK: - Initial State

    @Test func testInitialState() {
        let vm = makeViewModel()

        #expect(vm.shareURL == nil)
        #expect(vm.showShareSheet == false)
        #expect(vm.shareError == nil)
        #expect(vm.isResending == false)
        #expect(vm.resendSuccess == nil)
        #expect(vm.serverStatus == .unknown)
        #expect(vm.isCheckingServer == false)
        #expect(vm.isSigning == false)
        #expect(vm.signSuccess == nil)
        #expect(vm.defaultIdentity == nil)
        #expect(vm.showProposeDetail == false)
        #expect(vm.contactNicknames.isEmpty)
        #expect(vm.pendingServerUpdate == nil)
        #expect(vm.isApplyingServerUpdate == false)
        #expect(vm.isHonoring == false)
        #expect(vm.isParting == false)
        #expect(vm.isDissolving == false)
        #expect(vm.pendingLocalResend == false)
        #expect(vm.isResendingLocalSignature == false)
    }

    // MARK: - otherParticipantNames

    @Test func testOtherParticipantNamesShowsBothKeysWhenNoIdentity() {
        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterKey")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = nil

        let names = vm.otherParticipantNames
        #expect(names.contains("creatorKey".prefix(12)))
        #expect(names.contains("counterKey".prefix(12)))
    }

    @Test func testOtherParticipantNamesExcludesSelf() {
        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterKey")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "creatorKey")

        let names = vm.otherParticipantNames
        #expect(names.contains("counterKey".prefix(12)))
        #expect(!names.contains("creatorKey".prefix(12)))
    }

    @Test func testOtherParticipantNamesUsesContactNickname() {
        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterKey")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "creatorKey")
        vm.contactNicknames = ["counterKey": "Alice"]

        #expect(vm.otherParticipantNames == "Alice")
    }

    @Test func testOtherParticipantNamesFallsBackToKeyPrefix() {
        let propose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyPublicKeyLong")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "creatorKey")

        #expect(vm.otherParticipantNames == "counterparty...")
    }

    // MARK: - shouldShowSignButton

    @Test func testShouldShowSignButtonFalseWhenNoIdentity() {
        let vm = makeViewModel()
        vm.defaultIdentity = nil

        #expect(vm.shouldShowSignButton == false)
    }

    @Test func testShouldShowSignButtonTrueWhenCounterpartyAndProposed() {
        let propose = makePropose(counterpartyPublicKey: "myKey", counterpartySignSignature: nil)
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        vm.pendingServerUpdate = nil
        vm.signSuccess = nil

        #expect(vm.shouldShowSignButton == true)
    }

    @Test func testShouldShowSignButtonFalseWhenCreator() {
        let propose = makePropose(creatorPublicKey: "myKey", counterpartyPublicKey: "otherKey")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")

        #expect(vm.shouldShowSignButton == false)
    }

    @Test func testShouldShowSignButtonFalseWhenPendingServerUpdate() {
        let propose = makePropose(counterpartyPublicKey: "myKey", counterpartySignSignature: nil)
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        vm.pendingServerUpdate = makeHashedPropose(for: propose)

        #expect(vm.shouldShowSignButton == false)
    }

    @Test func testShouldShowSignButtonFalseWhenSignSuccessIsTrue() {
        let propose = makePropose(counterpartyPublicKey: "myKey", counterpartySignSignature: nil)
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        vm.signSuccess = true

        #expect(vm.shouldShowSignButton == false)
    }

    @Test func testShouldShowSignButtonFalseWhenAlreadySigned() {
        let propose = makePropose(counterpartyPublicKey: "myKey", counterpartySignSignature: "existingSig")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")

        #expect(vm.shouldShowSignButton == false)
    }

    // MARK: - loadDefaultIdentity

    @Test func testLoadDefaultIdentitySetsIdentityOnSuccess() async {
        let identityID = UUID()
        let identity = Identity(id: identityID, nickname: "Alice", publicKey: "alicePubKey")
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

    // MARK: - loadContactNicknames

    @Test func testLoadContactNicknamesBuildsMappingOnSuccess() {
        let contacts = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "aliceKey", createdAt: .now),
            Contact(id: UUID(), nickname: "Bob", publicKey: "bobKey", createdAt: .now)
        ]
        let deps = MockDependencyContainer()
        (deps.contactRepository as! MockContactRepository).fetchAllResult = contacts

        let vm = makeViewModel(deps: deps)
        vm.loadContactNicknames()

        #expect(vm.contactNicknames["aliceKey"] == "Alice")
        #expect(vm.contactNicknames["bobKey"] == "Bob")
    }

    @Test func testLoadContactNicknamesRemainsEmptyOnError() {
        let deps = MockDependencyContainer()
        (deps.contactRepository as! MockContactRepository).fetchAllError = ContactRepositoryError.fetchError(
            NSError(domain: "test", code: 0)
        )

        let vm = makeViewModel(deps: deps)
        vm.loadContactNicknames()

        #expect(vm.contactNicknames.isEmpty)
    }
}
