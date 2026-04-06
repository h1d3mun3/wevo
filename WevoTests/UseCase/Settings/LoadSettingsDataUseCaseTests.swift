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
    let mockContactRepository = MockContactRepository()

    @Test("Can fetch all data at once")
    func executeSuccess() throws {
        let propose = Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "Test",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )
        let space = Space(id: UUID(), name: "Space", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockProposeRepository.fetchAllNoFilterResult = [propose]
        mockSpaceRepository.fetchAllResult = [space]

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            contactRepository: mockContactRepository
        )

        let data = try useCase.execute()

        #expect(data.proposes.count == 1)
        #expect(data.spaces.count == 1)
        #expect(data.proposes[0].id == propose.id)
        #expect(data.spaces[0].id == space.id)
    }

    @Test("Works correctly even when data is empty")
    func executeWithEmptyData() throws {
        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            contactRepository: mockContactRepository
        )

        let data = try useCase.execute()

        #expect(data.proposes.isEmpty)
        #expect(data.spaces.isEmpty)
        #expect(data.contacts.isEmpty)
    }

    @Test("Returns error when Propose fetch fails")
    func executeFailsWhenProposeFetchFails() {
        mockProposeRepository.fetchAllNoFilterError = ProposeRepositoryError.fetchError(NSError(domain: "", code: -1))

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            contactRepository: mockContactRepository
        )

        #expect(throws: ProposeRepositoryError.self) {
            _ = try useCase.execute()
        }
    }

    @Test("Returns error when Space fetch fails")
    func executeFailsWhenSpaceFetchFails() {
        mockSpaceRepository.fetchAllError = SpaceRepositoryError.fetchError(NSError(domain: "", code: -1))

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            contactRepository: mockContactRepository
        )

        #expect(throws: SpaceRepositoryError.self) {
            _ = try useCase.execute()
        }
    }

    @Test("Returns error when Contact fetch fails")
    func executeFailsWhenContactFetchFails() {
        mockContactRepository.fetchAllError = ContactRepositoryError.fetchError(NSError(domain: "", code: -1))

        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: mockProposeRepository,
            spaceRepository: mockSpaceRepository,
            contactRepository: mockContactRepository
        )

        #expect(throws: ContactRepositoryError.self) {
            _ = try useCase.execute()
        }
    }
}
