//
//  MergeServerSignaturesIntoLocalProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

protocol MergeServerSignaturesIntoLocalProposeUseCase {
    /// Reflect server signatures and timestamps in the local Propose
    /// - Parameters:
    ///   - proposeID: ID of the target Propose
    ///   - serverPropose: Server's HashedPropose containing all signatures and timestamps
    func execute(proposeID: UUID, serverPropose: HashedPropose) throws
}

struct MergeServerSignaturesIntoLocalProposeUseCaseImpl {
    let proposeRepository: ProposeRepository
    let keychainRepository: KeychainRepository

    init(proposeRepository: ProposeRepository, keychainRepository: KeychainRepository) {
        self.proposeRepository = proposeRepository
        self.keychainRepository = keychainRepository
    }
}

extension MergeServerSignaturesIntoLocalProposeUseCaseImpl: MergeServerSignaturesIntoLocalProposeUseCase {
    func execute(proposeID: UUID, serverPropose: HashedPropose) throws {
        let localPropose = try proposeRepository.fetch(by: proposeID)
        let counterparty = serverPropose.counterparties.first

        // Signature messages are bound to the LOCAL propose's identity (id, content hash) and the
        // LOCAL participant keys — never anything the server supplies — so a hostile server/MITM
        // cannot substitute keys/content to make forged signatures verify.
        let id = localPropose.id.uuidString
        let hash = localPropose.payloadHash
        let creatorKey = localPropose.creatorPublicKey
        let cpKey = localPropose.counterpartyPublicKey

        /// Adopts a server-provided signature only when the local slot is empty AND the signature
        /// cryptographically verifies (v1: "<verb>." + id + hash + signerKey + timestamp) against
        /// the local participant key. Otherwise the local value is kept and the forged/invalid
        /// server value is rejected — so unverified server data can never be persisted or trusted.
        func adopt(localSig: String?, localTs: String?,
                   serverSig: String?, serverTs: String?,
                   verb: String, signerKey: String) -> (String?, String?) {
            guard localSig == nil, let serverSig, let serverTs else { return (localSig, localTs) }
            let message = verb + "." + id + hash + signerKey + serverTs
            if (try? keychainRepository.verifySignature(serverSig, for: message, withPublicKeyString: signerKey)) == true {
                return (serverSig, serverTs)
            }
            Logger.propose.warning("Rejected unverified server '\(verb, privacy: .public)' signature for \(localPropose.id, privacy: .private)")
            return (localSig, localTs)
        }

        let cpSign = adopt(localSig: localPropose.counterpartySignSignature, localTs: localPropose.counterpartySignTimestamp,
                           serverSig: counterparty?.signSignature, serverTs: counterparty?.signTimestamp, verb: "signed", signerKey: cpKey)
        let cpHonor = adopt(localSig: localPropose.counterpartyHonorSignature, localTs: localPropose.counterpartyHonorTimestamp,
                            serverSig: counterparty?.honorSignature, serverTs: counterparty?.honorTimestamp, verb: "honored", signerKey: cpKey)
        let cpPart = adopt(localSig: localPropose.counterpartyPartSignature, localTs: localPropose.counterpartyPartTimestamp,
                           serverSig: counterparty?.partSignature, serverTs: counterparty?.partTimestamp, verb: "parted", signerKey: cpKey)
        let cpDissolve = adopt(localSig: localPropose.counterpartyDissolveSignature, localTs: localPropose.counterpartyDissolveTimestamp,
                               serverSig: counterparty?.dissolveSignature, serverTs: counterparty?.dissolveTimestamp, verb: "dissolved", signerKey: cpKey)
        let crHonor = adopt(localSig: localPropose.creatorHonorSignature, localTs: localPropose.creatorHonorTimestamp,
                            serverSig: serverPropose.honorCreatorSignature, serverTs: serverPropose.honorCreatorTimestamp, verb: "honored", signerKey: creatorKey)
        let crPart = adopt(localSig: localPropose.creatorPartSignature, localTs: localPropose.creatorPartTimestamp,
                           serverSig: serverPropose.partCreatorSignature, serverTs: serverPropose.partCreatorTimestamp, verb: "parted", signerKey: creatorKey)
        let crDissolve = adopt(localSig: localPropose.creatorDissolveSignature, localTs: localPropose.creatorDissolveTimestamp,
                               serverSig: serverPropose.creatorDissolveSignature, serverTs: serverPropose.creatorDissolveTimestamp, verb: "dissolved", signerKey: creatorKey)

        let updatedPropose = Propose(
            id: localPropose.id,
            spaceID: localPropose.spaceID,
            message: localPropose.message,
            creatorPublicKey: localPropose.creatorPublicKey,
            creatorSignature: localPropose.creatorSignature,
            counterpartyPublicKey: localPropose.counterpartyPublicKey,
            counterpartySignSignature: cpSign.0,
            counterpartySignTimestamp: cpSign.1,
            counterpartyHonorSignature: cpHonor.0,
            counterpartyHonorTimestamp: cpHonor.1,
            counterpartyPartSignature: cpPart.0,
            counterpartyPartTimestamp: cpPart.1,
            creatorHonorSignature: crHonor.0,
            creatorHonorTimestamp: crHonor.1,
            creatorPartSignature: crPart.0,
            creatorPartTimestamp: crPart.1,
            creatorDissolveSignature: crDissolve.0,
            creatorDissolveTimestamp: crDissolve.1,
            counterpartyDissolveSignature: cpDissolve.0,
            counterpartyDissolveTimestamp: cpDissolve.1,
            signatureVersion: localPropose.signatureVersion,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        try proposeRepository.update(updatedPropose)
        Logger.propose.info("Reflected verified server signatures locally: \(localPropose.id, privacy: .private)")
    }
}
