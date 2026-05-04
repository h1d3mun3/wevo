//
//  ProposeRowViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class ProposeRowViewModel {
    var propose: Propose
    let space: Space
    private let deps: any DependencyContainer

    var shareURL: URL?
    var showShareSheet = false
    var shareError: String?

    var isResending = false
    var resendSuccess: Bool?
    var resendErrorMessage: String?

    var serverStatus: ProposeServerStatus = .unknown
    var isCheckingServer = false

    var isSigning = false
    var signSuccess: Bool?
    var signErrorMessage: String?

    var defaultIdentity: Identity?
    var showProposeDetail = false
    var contactNicknames: [String: String] = [:]

    var pendingServerUpdate: HashedPropose?
    var isApplyingServerUpdate = false

    var isHonoring = false
    var honorSuccess: Bool?
    var honorErrorMessage: String?
    var myHonorSigned = false

    var isParting = false
    var partSuccess: Bool?
    var partErrorMessage: String?
    var myPartSigned = false

    var isDissolving = false
    var dissolveSuccess: Bool?
    var dissolveErrorMessage: String?

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
        return canSign && pendingServerUpdate == nil && signSuccess != true
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
        isResending = true
        resendSuccess = nil
        resendErrorMessage = nil

        let useCase = ResendProposeToServerUseCaseImpl()
        do {
            try await useCase.execute(propose: propose, serverURLs: space.urls)
            isResending = false
            resendSuccess = true
            serverStatus = .exists

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            resendSuccess = nil
        } catch {
            Logger.propose.error("Propose resend error: \(error, privacy: .public)")
            isResending = false
            resendSuccess = false
            resendErrorMessage = error.localizedDescription

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            resendSuccess = nil
            resendErrorMessage = nil
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
        isSigning = true
        signSuccess = nil
        signErrorMessage = nil

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            isSigning = false
            signSuccess = true

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            signSuccess = nil
        } catch SignProposeUseCaseError.notCounterparty {
            Logger.propose.warning("This identity is not the Counterparty and cannot sign")
            isSigning = false
            signSuccess = false
            signErrorMessage = "This identity is not the Counterparty"

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            signSuccess = nil
            signErrorMessage = nil
        } catch {
            Logger.propose.error("Signing error: \(error, privacy: .public)")
            isSigning = false
            signSuccess = false
            signErrorMessage = error.localizedDescription

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            signSuccess = nil
            signErrorMessage = nil
        }
    }

    func dissolvePropose(with identity: Identity) async {
        isDissolving = true
        dissolveSuccess = nil
        dissolveErrorMessage = nil

        let useCase = DissolveProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            isDissolving = false
            dissolveSuccess = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dissolveSuccess = nil
        } catch {
            Logger.propose.error("Dissolve error: \(error, privacy: .public)")
            isDissolving = false
            dissolveSuccess = false
            dissolveErrorMessage = error.localizedDescription
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            dissolveSuccess = nil
            dissolveErrorMessage = nil
        }
    }

    func honorPropose(with identity: Identity) async {
        isHonoring = true
        honorSuccess = nil
        honorErrorMessage = nil

        let useCase = HonorProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            isHonoring = false
            honorSuccess = true
            myHonorSigned = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            honorSuccess = nil
        } catch {
            Logger.propose.error("Honor error: \(error, privacy: .public)")
            isHonoring = false
            honorSuccess = false
            honorErrorMessage = error.localizedDescription
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            honorSuccess = nil
            honorErrorMessage = nil
        }
    }

    func partPropose(with identity: Identity) async {
        isParting = true
        partSuccess = nil
        partErrorMessage = nil

        let useCase = PartProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURLs: space.urls)
            isParting = false
            partSuccess = true
            myPartSigned = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            partSuccess = nil
        } catch {
            Logger.propose.error("Part error: \(error, privacy: .public)")
            isParting = false
            partSuccess = false
            partErrorMessage = error.localizedDescription
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            partSuccess = nil
            partErrorMessage = nil
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
            isApplyingServerUpdate = false
            pendingServerUpdate = nil
            Logger.propose.info("Accepted server signatures and reflected them locally")
        } catch {
            Logger.propose.error("Failed to reflect server signatures locally: \(error, privacy: .public)")
            isApplyingServerUpdate = false
        }
    }
}
