//
//  MockProposeAPIClient.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Foundation
@testable import Wevo

class MockProposeAPIClient: ProposeAPIClientProtocol {
    // MARK: - createPropose
    var createProposeCalled = false
    var createProposeInput: ProposeAPIClient.ProposeInput?
    var createProposeError: Error?

    // MARK: - updatePropose
    var updateProposeCalled = false
    var updateProposeID: UUID?
    var updateProposeInput: ProposeAPIClient.ProposeInput?
    var updateProposeError: Error?

    // MARK: - getPropose
    var getProposeResult: HashedPropose?
    var getProposeError: Error?
    var getProposeCalledWithID: UUID?

    // MARK: - listProposes
    var listProposesResult: ProposeAPIClient.Page<HashedPropose>?
    var listProposesError: Error?

    // MARK: - Protocol Implementation

    func createPropose(input: ProposeAPIClient.ProposeInput) async throws {
        createProposeCalled = true
        createProposeInput = input

        if let error = createProposeError {
            throw error
        }
    }

    func updatePropose(proposeID: UUID, input: ProposeAPIClient.ProposeInput) async throws {
        updateProposeCalled = true
        updateProposeID = proposeID
        updateProposeInput = input

        if let error = updateProposeError {
            throw error
        }
    }

    func getPropose(proposeID: UUID) async throws -> HashedPropose {
        getProposeCalledWithID = proposeID

        if let error = getProposeError {
            throw error
        }
        guard let result = getProposeResult else {
            throw NSError(domain: "MockProposeAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result set"])
        }
        return result
    }

    func listProposes(publicKey: String, page: Int, per: Int) async throws -> ProposeAPIClient.Page<HashedPropose> {
        if let error = listProposesError {
            throw error
        }
        guard let result = listProposesResult else {
            throw NSError(domain: "MockProposeAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result set"])
        }
        return result
    }
}
