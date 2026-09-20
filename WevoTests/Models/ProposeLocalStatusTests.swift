//
//  ProposeLocalStatusTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct ProposeLocalStatusTests {

    private func makePropose(
        counterpartySignSignature: String? = nil,
        creatorHonorSignature: String? = nil,
        counterpartyHonorSignature: String? = nil,
        creatorPartSignature: String? = nil,
        counterpartyPartSignature: String? = nil,
        creatorDissolveSignature: String? = nil,
        counterpartyDissolveSignature: String? = nil
    ) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "test message",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: counterpartySignSignature,
            counterpartyHonorSignature: counterpartyHonorSignature,
            counterpartyPartSignature: counterpartyPartSignature,
            creatorHonorSignature: creatorHonorSignature,
            creatorPartSignature: creatorPartSignature,
            creatorDissolveSignature: creatorDissolveSignature,
            counterpartyDissolveSignature: counterpartyDissolveSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testProposedWhenNoSignatures() {
        let propose = makePropose()
        #expect(propose.localStatus == .proposed)
    }

    @Test func testSignedWhenCounterpartyHasSigned() {
        let propose = makePropose(counterpartySignSignature: "sig")
        #expect(propose.localStatus == .signed)
    }

    @Test func testPartedWhenCreatorHasParted() {
        let propose = makePropose(counterpartySignSignature: "sig", creatorPartSignature: "partSig")
        #expect(propose.localStatus == .parted)
    }

    @Test func testPartedWhenCounterpartyHasParted() {
        let propose = makePropose(counterpartySignSignature: "sig", counterpartyPartSignature: "partSig")
        #expect(propose.localStatus == .parted)
    }

    @Test func testHonoredWhenBothPartiesHaveHonored() {
        let propose = makePropose(
            counterpartySignSignature: "sig",
            creatorHonorSignature: "creatorHonor",
            counterpartyHonorSignature: "counterpartyHonor"
        )
        #expect(propose.localStatus == .honored)
    }

    @Test func testNotHonoredWhenOnlyCreatorHasHonored() {
        let propose = makePropose(counterpartySignSignature: "sig", creatorHonorSignature: "creatorHonor")
        #expect(propose.localStatus == .signed)
    }

    @Test func testDissolvedWhenCreatorHasDissolved() {
        let propose = makePropose(creatorDissolveSignature: "dissolveSig")
        #expect(propose.localStatus == .dissolved)
    }

    @Test func testDissolvedWhenCounterpartyHasDissolved() {
        let propose = makePropose(counterpartyDissolveSignature: "dissolveSig")
        #expect(propose.localStatus == .dissolved)
    }

    @Test func testDissolvedTakesPriorityOverHonored() {
        // dissolve takes priority over all other states
        let propose = makePropose(
            counterpartySignSignature: "sig",
            creatorHonorSignature: "creatorHonor",
            counterpartyHonorSignature: "counterpartyHonor",
            creatorDissolveSignature: "dissolveSig"
        )
        #expect(propose.localStatus == .dissolved)
    }

    @Test func testDissolvedTakesPriorityOverParted() {
        let propose = makePropose(
            counterpartySignSignature: "sig",
            creatorPartSignature: "partSig",
            creatorDissolveSignature: "dissolveSig"
        )
        #expect(propose.localStatus == .dissolved)
    }
}
