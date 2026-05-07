//
//  ProposeRowViewModel.swift
//  Wevo
//

import SwiftUI
import os

enum AsyncOperationState: Equatable {
    case idle
    case running
    case succeeded
    case failed(String)
}

@Observable
@MainActor
final class ProposeRowViewModel {
    var propose: Propose
    let space: Space
    private let deps: any DependencyContainer

    var shareURL: URL?
    var showShareSheet = false
    var shareError: String?

    var resendState: AsyncOperationState = .idle
    var serverStatus: ProposeServerStatus = .unknown
    var isCheckingServer = false

    var signState: AsyncOperationState = .idle

    var defaultIdentity: Identity?
    var showProposeDetail = false
    var contactNicknames: [String: String] = [:]

    var pendingServerUpdate: HashedPropose?
    var isApplyingServerUpdate = false

    var honorState: AsyncOperationState = .idle
    var myHonorSigned = false

    var partState: AsyncOperationState = .idle
    var myPartSigned = false

    var dissolveState: AsyncOperationState = .idle

    var pendingLocalResend = false
    var isResendingLocalSignature = false

    var otherParticipantNames: String {
        let myKey = defaultIdentity?.publicKey
        let otherKeys = propose.allParticipantPublicKeys.filter { $0 != myKey }
        if otherKeys.isEmpty { return "..." }
        return otherKeys
            .map { contactNicknames[$0] ?? String($0.prefix(12)) + "..." }
            .joined(separator: ", ")
    }

    var shouldShowSignButton: Bool {
        guard let identity = defaultIdentity else { return false }
        let canSign = CanSignProposeUseCaseImpl().execute(identity: identity, propose: propose)
        return canSign && pendingServerUpdate == nil && signState != .succeeded
    }

    var hasLocallyHonored: Bool {
        guard let identity = defaultIdentity else { return false }
        return identity.publicKey == propose.creatorPublicKey
            ? propose.creatorHonorSignature != nil
            : propose.counterpartyHonorSignature != nil
    }

    var hasLocallyParted: Bool {
        guard let identity = defaultIdentity else { return false }
        return identity.publicKey == propose.creatorPublicKey
            ? propose.creatorPartSignature != nil
            : propose.counterpartyPartSignature != nil
    }

    init(propose: Propose, space: Space, deps: any DependencyContainer) {
        self.propose = propose
        self.space = space
        self.deps = deps
    }

    // MARK: - Actions

    func prepareShare() {
        let useCase = ExportProposeUseCaseImpl()
        do {
            shareURL = try useCase.execute(propose: propose, space: space)
            shareError = nil
        } catch {
            Logger.propose.error("Propose export error: \(error, privacy: .public)")
            shareError = "Export failed"
        }
    }

    func sharePropose() {
        if shareURL == nil { prepareShare() }
        showShareSheet = true
    }

    func resendToServer() async {
        resendState = .running

        let useCase = ResendProposeToServerUseCaseImpl()
        do {
            try await useCase.execute(propose: propose, serverURLs: space.urls)
            resendState = .succeeded
            serverStatus = .exists

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            resendState = .idle
        } catch {
            Logger.propose.error("Propose resend error: \(error, privacy: .public)")
            resendState = .failed(error.localizedDescription)

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            resendState = .idle
        }
    }

    func checkServerStatus() async {
        guard !isCheckingServer else { return }
        isCheckingServer = true
        serverStatus = .checking

        let useCase = CheckProposeServerStatusUseCaseImpl()
        do {
            let myPublicKey = defaultIdentity?.publicKey
            let result = try await useCase.execute(propose: propose, serverURLs: space.urls, myPublicKey: myPublicKey)
            serverStatus = .exists
            isCheckingServer = false
            pendingServerUpdate = result.pendingServerUpdate
            myHonorSigned = result.myHonorSigned
            myPartSigned = result.myPartSigned
            pendingLocalResend = result.pendingLocalResend
        } catch CheckProposeServerStatusUseCaseError.proposeNotFound {
            Logger.propose.info("Propose not found on server: \(self.propose.id, privacy: .private)")
            serverStatus = .notFound
            isCheckingServer = false
        } catch {
            Logger.propose.warning("Server status check error: \(error, privacy: .public)")
            serverStatus = .error(error.localizedDescription)
            isCheckingServer = false
        }
    }

    func loadDefaultIdentity() async {
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            defaultIdentity = try useCase.execute(space: space)
        } catch {
            Logger.identity.error("Error loading default Identity: \(error, privacy: .public)")
            defaultIdentity = nil
        }
    }

    func loadContactNicknames() {
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            contactNicknames = try useCase.execute()
        } catch {
            Logger.contact.error("Error loading contact nicknames: \(error, privacy: .public)")
        }
    }

    func signPropose(with identity: Identity) async {
        signState = .running

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            if let latest = try? deps.proposeRepository.fetch(by: propose.id) {
                self.propose = latest
            }
            pendingServerUpdate = nil
            signState = .succeeded

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            signState = .idle
        } catch SignProposeUseCaseError.notCounterparty {
            Logger.propose.warning("This identity is not the Counterparty and cannot sign")
            signState = .failed("This identity is not the Counterparty")

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            signState = .idle
        } catch {
            Logger.propose.error("Signing error: \(error, privacy: .public)")
            signState = .failed(error.localizedDescription)

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            signState = .idle
        }
    }

    func dissolvePropose(with identity: Identity) async {
        dissolveState = .running

        let useCase = DissolveProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            if let latest = try? deps.proposeRepository.fetch(by: propose.id) {
                self.propose = latest
            }
            pendingServerUpdate = nil
            dissolveState = .succeeded
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dissolveState = .idle
        } catch {
            Logger.propose.error("Dissolve error: \(error, privacy: .public)")
            dissolveState = .failed(error.localizedDescription)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            dissolveState = .idle
        }
    }

    func honorPropose(with identity: Identity) async {
        honorState = .running

        let useCase = HonorProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            if let latest = try? deps.proposeRepository.fetch(by: propose.id) {
                self.propose = latest
            }
            pendingServerUpdate = nil
            honorState = .succeeded
            myHonorSigned = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            honorState = .idle
        } catch {
            Logger.propose.error("Honor error: \(error, privacy: .public)")
            honorState = .failed(error.localizedDescription)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            honorState = .idle
        }
    }

    func partPropose(with identity: Identity) async {
        partState = .running

        let useCase = PartProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            if let latest = try? deps.proposeRepository.fetch(by: propose.id) {
                self.propose = latest
            }
            pendingServerUpdate = nil
            partState = .succeeded
            myPartSigned = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            partState = .idle
        } catch {
            Logger.propose.error("Part error: \(error, privacy: .public)")
            partState = .failed(error.localizedDescription)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            partState = .idle
        }
    }

    func resendLocalSignature() async {
        guard let identity = defaultIdentity else { return }
        isResendingLocalSignature = true

        let useCase = ResendMissingLocalSignaturesToServerUseCaseImpl()
        do {
            try await useCase.execute(
                propose: propose,
                identityPublicKey: identity.publicKey,
                serverURLs: space.urls
            )
            isResendingLocalSignature = false
            pendingLocalResend = false
            Logger.propose.info("Resent local signature to server: \(self.propose.id, privacy: .private)")
        } catch {
            Logger.propose.error("Local signature resend error: \(error, privacy: .public)")
            isResendingLocalSignature = false
        }
    }

    func acceptServerPropose(_ serverPropose: HashedPropose) async {
        isApplyingServerUpdate = true

        let useCase = MergeServerSignaturesIntoLocalProposeUseCaseImpl(proposeRepository: deps.proposeRepository)
        do {
            try useCase.execute(proposeID: propose.id, serverPropose: serverPropose)
            if let latest = try? deps.proposeRepository.fetch(by: propose.id) {
                self.propose = latest
            }
            isApplyingServerUpdate = false
            pendingServerUpdate = nil
            Logger.propose.info("Accepted server signatures and reflected them locally")
        } catch {
            Logger.propose.error("Failed to reflect server signatures locally: \(error, privacy: .public)")
            isApplyingServerUpdate = false
        }
    }
}
