//
//  ResendProposeToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

protocol ResendProposeToServerUseCase {
    func execute(propose: Propose, serverURLs: [String]) async throws
}

enum ResendProposeToServerUseCaseError: Error {
    case invalidServerURL
    case noSignatureFound
}

struct ResendProposeToServerUseCaseImpl {
    let apiClient: ProposeAPIClientProtocol?

    init(apiClient: ProposeAPIClientProtocol? = nil) {
        self.apiClient = apiClient
    }
}

extension ResendProposeToServerUseCaseImpl: ResendProposeToServerUseCase {
    func execute(propose: Propose, serverURLs: [String]) async throws {
        guard !serverURLs.isEmpty else {
            throw ResendProposeToServerUseCaseError.invalidServerURL
        }

        // Verify that CreatorSignature exists
        guard !propose.creatorSignature.isEmpty else {
            throw ResendProposeToServerUseCaseError.noSignatureFound
        }

        // ISO8601 string of creation timestamp
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)

        // Resend to POST /proposes using CreateProposeInput
        let input = ProposeAPIClient.CreateProposeInput(
            proposeId: propose.id.uuidString,
            contentHash: propose.payloadHash,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKeys: [propose.counterpartyPublicKey],
            createdAt: iso8601String
        )

        let client = apiClient ?? ResilientProposeAPIClient(urls: serverURLs)
        try await client.createPropose(input: input)

        Logger.propose.info("Resent Propose to server: \(propose.id, privacy: .private)")
    }
}
