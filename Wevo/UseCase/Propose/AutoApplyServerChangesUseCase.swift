//
//  AutoApplyServerChangesUseCase.swift
//  Wevo
//
//  Created on 3/17/26.
//

import Foundation

protocol AutoApplyServerChangesUseCase {
    /// Checks server status for the given propose and automatically applies any pending changes
    /// (counterparty signatures or terminal status transitions) to local SwiftData.
    /// - Parameters:
    ///   - propose: The local Propose to check
    ///   - serverURL: The server base URL string
    ///   - myPublicKey: The current user's public key (used to determine which signatures belong to us)
    func execute(propose: Propose, serverURL: String, myPublicKey: String?) async throws
}

struct AutoApplyServerChangesUseCaseImpl {
    let apiClient: ProposeAPIClientProtocol?
    let proposeRepository: ProposeRepository

    init(apiClient: ProposeAPIClientProtocol? = nil, proposeRepository: ProposeRepository) {
        self.apiClient = apiClient
        self.proposeRepository = proposeRepository
    }
}

extension AutoApplyServerChangesUseCaseImpl: AutoApplyServerChangesUseCase {
    func execute(propose: Propose, serverURL: String, myPublicKey: String?) async throws {
        let checkUseCase = CheckProposeServerStatusUseCaseImpl(apiClient: apiClient)
        let result = try await checkUseCase.execute(propose: propose, serverURL: serverURL, myPublicKey: myPublicKey)

        if let pendingServerPropose = result.pendingServerPropose {
            let appendUseCase = AppendServerSignaturesToLocalProposeUseCaseImpl(proposeRepository: proposeRepository)
            try appendUseCase.execute(proposeID: propose.id, serverPropose: pendingServerPropose)
        }

        if let pendingStatusTransition = result.pendingStatusTransition {
            let applyStatusUseCase = ApplyServerStatusToLocalProposeUseCaseImpl(proposeRepository: proposeRepository)
            try applyStatusUseCase.execute(proposeID: propose.id, status: pendingStatusTransition)
        }
    }
}
