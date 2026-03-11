//
//  LoadSettingsDataUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct LoadSettingsDataUseCaseTests {

    let mockProposeRepository = MockProposeRepository()
    let mockSpaceRepository = MockSpaceRepository()
    let mockSignatureRepository = MockSignatureRepository()

    @Test("全データを一括で取得できる")
    func executeSuccess() throws {
        let propose = Propose(id: UUID(), spaceID: UUID(), message: "Test", signatures: [], createdAt: .now, updatedAt: .now)
        let space = Space(id: UUID(), name: "Space", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)
        let signature = Signature(id: UUID(), publicKey: "PK", signature: "Sig", createdAt: .now)

        mockProposeRepository.fetchAllNoFilterResult = [propose]
        mockSpaceRepository.fetchAllResult = [space]
        mockSignatureRepository.fetchAllResult = [signature]

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            signatureRepository: mockSignatureRepository
        )

        let data = try useCase.execute()

        #expect(data.proposes.count == 1)
        #expect(data.spaces.count == 1)
        #expect(data.signatures.count == 1)
        #expect(data.proposes[0].id == propose.id)
        #expect(data.spaces[0].id == space.id)
        #expect(data.signatures[0].id == signature.id)
    }

    @Test("データが空の場合も正常に動作する")
    func executeWithEmptyData() throws {
        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            signatureRepository: mockSignatureRepository
        )

        let data = try useCase.execute()

        #expect(data.proposes.isEmpty)
        #expect(data.spaces.isEmpty)
        #expect(data.signatures.isEmpty)
    }

    @Test("Propose取得に失敗した場合エラーが返る")
    func executeFailsWhenProposeFetchFails() {
        mockProposeRepository.fetchAllNoFilterError = ProposeRepositoryError.fetchError(NSError(domain: "", code: -1))

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            signatureRepository: mockSignatureRepository
        )

        #expect(throws: ProposeRepositoryError.self) {
            _ = try useCase.execute()
        }
    }

    @Test("Space取得に失敗した場合エラーが返る")
    func executeFailsWhenSpaceFetchFails() {
        mockSpaceRepository.fetchAllError = SpaceRepositoryError.fetchError(NSError(domain: "", code: -1))

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            signatureRepository: mockSignatureRepository
        )

        #expect(throws: SpaceRepositoryError.self) {
            _ = try useCase.execute()
        }
    }

    @Test("Signature取得に失敗した場合エラーが返る")
    func executeFailsWhenSignatureFetchFails() {
        mockSignatureRepository.fetchAllError = SignatureRepositoryError.fetchError(NSError(domain: "", code: -1))

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            signatureRepository: mockSignatureRepository
        )

        #expect(throws: SignatureRepositoryError.self) {
            _ = try useCase.execute()
        }
    }
}
