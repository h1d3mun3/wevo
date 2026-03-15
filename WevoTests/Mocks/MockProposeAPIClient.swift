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
    var createProposeInput: ProposeAPIClient.CreateProposeInput?
    var createProposeError: Error?

    // MARK: - signPropose
    var signProposeCalled = false
    var signProposeID: UUID?
    var signProposeInput: ProposeAPIClient.SignInput?
    var signProposeError: Error?

    // MARK: - dissolvePropose
    var dissolveProposeCalled = false
    var dissolveProposeProposeID: UUID?
    var dissolveProposeinput: ProposeAPIClient.TransitionInput?
    var dissolveProposeerror: Error?

    // MARK: - honorPropose
    var honorProposeCalled = false
    var honorProposeProposeID: UUID?
    var honorProposeinput: ProposeAPIClient.TransitionInput?
    var honorProposeerror: Error?

    // MARK: - partPropose
    var partProposeCalled = false
    var partProposeProposeID: UUID?
    var partProposeinput: ProposeAPIClient.TransitionInput?
    var partProposeerror: Error?

    // MARK: - getPropose
    var getProposeResult: HashedPropose?
    var getProposeError: Error?
    var getProposeCalledWithID: UUID?

    // MARK: - listProposes
    var listProposesResult: ProposeAPIClient.Page<HashedPropose>?
    var listProposesError: Error?

    // MARK: - Protocol Implementation

    func createPropose(input: ProposeAPIClient.CreateProposeInput) async throws {
        createProposeCalled = true
        createProposeInput = input

        if let error = createProposeError {
            throw error
        }
    }

    func signPropose(proposeID: UUID, input: ProposeAPIClient.SignInput) async throws {
        signProposeCalled = true
        signProposeID = proposeID
        signProposeInput = input

        if let error = signProposeError {
            throw error
        }
    }

    func dissolvePropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws {
        dissolveProposeCalled = true
        dissolveProposeProposeID = proposeID
        dissolveProposeinput = input

        if let error = dissolveProposeerror {
            throw error
        }
    }

    func honorPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws {
        honorProposeCalled = true
        honorProposeProposeID = proposeID
        honorProposeinput = input

        if let error = honorProposeerror {
            throw error
        }
    }

    func partPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws {
        partProposeCalled = true
        partProposeProposeID = proposeID
        partProposeinput = input

        if let error = partProposeerror {
            throw error
        }
    }

    func getPropose(proposeID: UUID) async throws -> HashedPropose {
        getProposeCalledWithID = proposeID

        if let error = getProposeError {
            throw error
        }
        guard let result = getProposeResult else {
            throw NSError(domain: "MockProposeAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "getProposeResultが設定されていません"])
        }
        return result
    }

    func listProposes(publicKey: String, status: String?, page: Int, per: Int) async throws -> ProposeAPIClient.Page<HashedPropose> {
        if let error = listProposesError {
            throw error
        }
        guard let result = listProposesResult else {
            throw NSError(domain: "MockProposeAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "listProposesResultが設定されていません"])
        }
        return result
    }
}
