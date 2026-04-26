//
//  ProposeSettingsDetailViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class ProposeSettingsDetailViewModel {
    var isHashValid: Bool?
    var contactNicknames: [String: String] = [:]

    var hasEventTimestamps: Bool {
        propose.counterpartySignTimestamp != nil
            || propose.creatorHonorTimestamp != nil
            || propose.counterpartyHonorTimestamp != nil
            || propose.creatorPartTimestamp != nil
            || propose.counterpartyPartTimestamp != nil
            || propose.creatorDissolveTimestamp != nil
            || propose.counterpartyDissolveTimestamp != nil
    }

    let propose: Propose

    private let deps: any DependencyContainer

    init(propose: Propose, deps: any DependencyContainer) {
        self.propose = propose
        self.deps = deps
    }

    func nickname(for publicKey: String) -> String {
        contactNicknames[publicKey] ?? String(publicKey.prefix(16)) + "..."
    }

    func load() async {
        await verifyHash()
        await loadContactNicknames()
    }

    private func verifyHash() async {
        let useCase = VerifyProposeHashUseCaseImpl()
        let isValid = useCase.execute(message: propose.message, payloadHash: propose.payloadHash)
        isHashValid = isValid
    }

    private func loadContactNicknames() async {
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            contactNicknames = try useCase.execute()
        } catch {
            Logger.contact.error("Error loading contact nicknames: \(error, privacy: .public)")
        }
    }
}
