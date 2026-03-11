//
//  MockDependencyContainer.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Foundation
@testable import Wevo

@MainActor
class MockDependencyContainer: DependencyContainer {
    var keychainRepository: KeychainRepository = MockKeychainRepository()
    var spaceRepository: SpaceRepository = MockSpaceRepository()
    var proposeRepository: ProposeRepository = MockProposeRepository()
    var signatureRepository: SignatureRepository = MockSignatureRepository()
}
