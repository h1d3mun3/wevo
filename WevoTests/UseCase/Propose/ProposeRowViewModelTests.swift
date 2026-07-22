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
        id: UUID = UUID(),
        spaceID: UUID = UUID(),
        creatorPublicKey: String = "creatorPubKey",
        counterpartyPublicKey: String = "counterpartyPubKey",
        counterpartySignSignature: String? = nil,
        creatorHonorSignature: String? = nil,
        counterpartyHonorSignature: String? = nil,
        creatorPartSignature: String? = nil,
        counterpartyPartSignature: String? = nil
    ) -> Propose {
        Propose(
            id: id,
            spaceID: spaceID,
            message: "test message",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            counterpartyHonorSignature: counterpartyHonorSignature,
            counterpartyPartSignature: counterpartyPartSignature,
            creatorHonorSignature: creatorHonorSignature,
            creatorPartSignature: creatorPartSignature,
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
        #expect(vm.shareError == nil)
        #expect(vm.resendState == .idle)
        #expect(vm.serverStatus == .unknown)
        #expect(vm.isCheckingServer == false)
        #expect(vm.signState == .idle)
        #expect(vm.defaultIdentity == nil)
        #expect(vm.showProposeDetail == false)
        #expect(vm.contactNicknames.isEmpty)
        #expect(vm.pendingServerUpdate == nil)
        #expect(vm.isApplyingServerUpdate == false)
        #expect(vm.honorState == .idle)
        #expect(vm.partState == .idle)
        #expect(vm.dissolveState == .idle)
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
        vm.signState = .idle

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
        vm.signState = .succeeded

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

    // MARK: - hasLocallyHonored

    @Test func testHasLocallyHonoredFalseWhenNoIdentity() {
        let vm = makeViewModel()
        vm.defaultIdentity = nil
        #expect(vm.hasLocallyHonored == false)
    }

    @Test func testHasLocallyHonoredTrueWhenCreatorHasHonorSignature() {
        let propose = makePropose(creatorPublicKey: "myKey", creatorHonorSignature: "honorSig")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyHonored == true)
    }

    @Test func testHasLocallyHonoredFalseWhenCreatorHasNoHonorSignature() {
        let propose = makePropose(creatorPublicKey: "myKey")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyHonored == false)
    }

    @Test func testHasLocallyHonoredTrueWhenCounterpartyHasHonorSignature() {
        let propose = makePropose(
            counterpartyPublicKey: "myKey",
            counterpartySignSignature: "signSig",
            counterpartyHonorSignature: "honorSig"
        )
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyHonored == true)
    }

    @Test func testHasLocallyHonoredFalseWhenCounterpartyHasNoHonorSignature() {
        let propose = makePropose(counterpartyPublicKey: "myKey", counterpartySignSignature: "signSig")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyHonored == false)
    }

    // MARK: - hasLocallyParted

    @Test func testHasLocallyPartedFalseWhenNoIdentity() {
        let vm = makeViewModel()
        vm.defaultIdentity = nil
        #expect(vm.hasLocallyParted == false)
    }

    @Test func testHasLocallyPartedTrueWhenCreatorHasPartSignature() {
        let propose = makePropose(creatorPublicKey: "myKey", creatorPartSignature: "partSig")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyParted == true)
    }

    @Test func testHasLocallyPartedFalseWhenCreatorHasNoPartSignature() {
        let propose = makePropose(creatorPublicKey: "myKey")
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyParted == false)
    }

    @Test func testHasLocallyPartedTrueWhenCounterpartyHasPartSignature() {
        let propose = makePropose(
            counterpartyPublicKey: "myKey",
            counterpartySignSignature: "signSig",
            counterpartyPartSignature: "partSig"
        )
        let vm = makeViewModel(propose: propose)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")
        #expect(vm.hasLocallyParted == true)
    }

    // MARK: - acceptServerPropose

    @Test func testAcceptServerProposeOnSuccessClearsPendingUpdateAndReloadsPropose() async {
        let proposeID = UUID()
        let spaceID = UUID()
        let originalPropose = makePropose(id: proposeID, spaceID: spaceID)
        let reloadedPropose = makePropose(
            id: proposeID,
            spaceID: spaceID,
            counterpartySignSignature: "signSig"
        )
        let serverPropose = makeHashedPropose(for: originalPropose)

        let deps = MockDependencyContainer()
        let mockRepo = deps.proposeRepository as! MockProposeRepository
        mockRepo.fetchByIDResult = reloadedPropose

        let vm = makeViewModel(propose: originalPropose, deps: deps)
        vm.pendingServerUpdate = serverPropose

        await vm.acceptServerPropose(serverPropose)

        #expect(vm.pendingServerUpdate == nil)
        #expect(vm.isApplyingServerUpdate == false)
        #expect(vm.propose.counterpartySignSignature == "signSig")
    }

    @Test func testAcceptServerProposeOnUseCaseFailureKeepsPendingUpdateAndResetsState() async {
        let proposeID = UUID()
        let originalPropose = makePropose(id: proposeID)
        let serverPropose = makeHashedPropose(for: originalPropose)

        let deps = MockDependencyContainer()
        let mockRepo = deps.proposeRepository as! MockProposeRepository
        // fetch fails → MergeServerSignaturesIntoLocalProposeUseCase throws → error path
        mockRepo.fetchByIDError = ProposeRepositoryError.proposeNotFound(proposeID)

        let vm = makeViewModel(propose: originalPropose, deps: deps)
        vm.pendingServerUpdate = serverPropose

        await vm.acceptServerPropose(serverPropose)

        #expect(vm.pendingServerUpdate != nil)
        #expect(vm.isApplyingServerUpdate == false)
        #expect(vm.propose.counterpartySignSignature == nil)
    }

    // MARK: - Local-only self-heal (BUG1)

    @Test func testCheckServerStatusLocalOnlyRestoresHonorStateFromRepository() async {
        let proposeID = UUID()
        // Stale row seed: I (creator) have not honored yet.
        let stalePropose = makePropose(id: proposeID, creatorPublicKey: "myKey", counterpartySignSignature: "signSig")
        // The store already holds my honor signature.
        let freshPropose = makePropose(id: proposeID, creatorPublicKey: "myKey", counterpartySignSignature: "signSig", creatorHonorSignature: "creatorHonorSig")

        let deps = MockDependencyContainer()
        let mockRepo = deps.proposeRepository as! MockProposeRepository
        mockRepo.fetchByIDResult = freshPropose

        let localSpace = Space(id: UUID(), name: "Local", url: "", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)
        let vm = makeViewModel(propose: stalePropose, space: localSpace, deps: deps)
        vm.defaultIdentity = Identity(id: UUID(), nickname: "Me", publicKey: "myKey")

        await vm.checkServerStatus()

        #expect(vm.serverStatus == .localOnly)
        #expect(vm.propose.creatorHonorSignature == "creatorHonorSig")  // re-synced from store
        #expect(vm.hasLocallyHonored == true)
        #expect(vm.myHonorSigned == true)  // restored so Honor/Part stay correctly disabled
    }

    @Test func testCheckServerStatusReportsLocalOnlyForSchemelessURL() async {
        // A non-empty but schemeless URL is local-only, not a server error (BUG4, UI side).
        let space = Space(id: UUID(), name: "S", url: "example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)
        let vm = makeViewModel(space: space)

        await vm.checkServerStatus()

        #expect(vm.serverStatus == .localOnly)
    }

    // MARK: - Space URL config change (BUG3)

    @Test func testUpdatingSpaceToRemoveServerURLMakesServerStatusLocalOnly() async {
        let spaceID = UUID()
        let serverSpace = Space(id: spaceID, name: "S", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)
        let vm = makeViewModel(space: serverSpace)

        // Simulate EditSpace removing the URL: the row VM must observe the live space.
        vm.space = Space(id: spaceID, name: "S", urls: [], defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)
        await vm.checkServerStatus()

        #expect(vm.serverStatus == .localOnly)
        #expect(vm.isCheckingServer == false)
    }

    // MARK: - Stale share invalidation (BUG2)

    @Test func testAcceptServerProposeClearsStaleShareURL() async {
        let proposeID = UUID()
        let original = makePropose(id: proposeID)
        let reloaded = makePropose(id: proposeID, counterpartySignSignature: "signSig")
        let serverPropose = makeHashedPropose(for: original)

        let deps = MockDependencyContainer()
        let mockRepo = deps.proposeRepository as! MockProposeRepository
        mockRepo.fetchByIDResult = reloaded

        let vm = makeViewModel(propose: original, deps: deps)
        vm.shareURL = URL(fileURLWithPath: "/tmp/stale.wevo-propose")

        await vm.acceptServerPropose(serverPropose)

        #expect(vm.shareURL == nil)  // prepared export invalidated when propose content changed
    }

    // MARK: - prepareShare error surfacing (BUG5)

    @Test func testPrepareShareSuccessSetsShareURLAndClearsError() {
        let vm = makeViewModel()
        vm.shareError = "stale"
        let url = URL(fileURLWithPath: "/tmp/propose.wevo-propose")

        vm.prepareShare(exportUseCase: StubExportProposeUseCase(result: .success(url)))

        #expect(vm.shareURL == url)
        #expect(vm.shareError == nil)
    }

    @Test func testPrepareShareFailureSetsShareErrorAndLeavesShareURLNil() {
        let vm = makeViewModel()
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])

        vm.prepareShare(exportUseCase: StubExportProposeUseCase(result: .failure(error)))

        #expect(vm.shareURL == nil)
        #expect(vm.shareError?.contains("disk full") == true)
    }
}

private struct StubExportProposeUseCase: ExportProposeUseCase {
    let result: Result<URL, Error>
    func execute(propose: Propose, space: Space) throws -> URL {
        try result.get()
    }
}
