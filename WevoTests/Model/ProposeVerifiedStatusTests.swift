//
//  ProposeVerifiedStatusTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct ProposeVerifiedStatusTests {

    private let creatorKey = "creatorKey"
    private let counterpartyKey = "counterpartyKey"

    /// A verifier that accepts a signature only when its value is in `accepted`. (The message and
    /// key arguments are exercised too, but tests key off the signature string for clarity.)
    private func verifier(accepting accepted: Set<String>) -> (String, String, String) -> Bool {
        { sig, _, _ in accepted.contains(sig) }
    }

    private func make(
        counterpartySignSignature: String? = nil,
        counterpartySignTimestamp: String? = nil,
        counterpartyHonorSignature: String? = nil,
        counterpartyHonorTimestamp: String? = nil,
        counterpartyPartSignature: String? = nil,
        counterpartyPartTimestamp: String? = nil,
        creatorHonorSignature: String? = nil,
        creatorHonorTimestamp: String? = nil,
        creatorPartSignature: String? = nil,
        creatorPartTimestamp: String? = nil,
        creatorDissolveSignature: String? = nil,
        creatorDissolveTimestamp: String? = nil,
        counterpartyDissolveSignature: String? = nil,
        counterpartyDissolveTimestamp: String? = nil
    ) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "m",
            creatorPublicKey: creatorKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyKey,
            counterpartySignSignature: counterpartySignSignature,
            counterpartySignTimestamp: counterpartySignTimestamp,
            counterpartyHonorSignature: counterpartyHonorSignature,
            counterpartyHonorTimestamp: counterpartyHonorTimestamp,
            counterpartyPartSignature: counterpartyPartSignature,
            counterpartyPartTimestamp: counterpartyPartTimestamp,
            creatorHonorSignature: creatorHonorSignature,
            creatorHonorTimestamp: creatorHonorTimestamp,
            creatorPartSignature: creatorPartSignature,
            creatorPartTimestamp: creatorPartTimestamp,
            creatorDissolveSignature: creatorDissolveSignature,
            creatorDissolveTimestamp: creatorDissolveTimestamp,
            counterpartyDissolveSignature: counterpartyDissolveSignature,
            counterpartyDissolveTimestamp: counterpartyDissolveTimestamp,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private let ts = "2026-01-01T00:00:00Z"

    @Test func testProposedWhenNoSignatures() {
        let p = make()
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: [])) == .proposed)
    }

    @Test func testSignedWhenCounterpartySignValid() {
        let p = make(counterpartySignSignature: "sign", counterpartySignTimestamp: ts)
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["sign"])) == .signed)
    }

    @Test func testHonoredWhenBothHonorsValid() {
        let p = make(
            counterpartyHonorSignature: "cpHonor", counterpartyHonorTimestamp: ts,
            creatorHonorSignature: "crHonor", creatorHonorTimestamp: ts
        )
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["cpHonor", "crHonor"])) == .honored)
    }

    @Test func testNotHonoredWhenOneHonorInvalid() {
        // Both honor fields present, but the counterparty's does not verify: must NOT show honored.
        let p = make(
            counterpartySignSignature: "sign", counterpartySignTimestamp: ts,
            counterpartyHonorSignature: "forged", counterpartyHonorTimestamp: ts,
            creatorHonorSignature: "crHonor", creatorHonorTimestamp: ts
        )
        // "forged" is rejected; only sign + creator honor accepted -> falls back to .signed.
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["sign", "crHonor"])) == .signed)
    }

    @Test func testPresenceOnlyWouldSayHonoredButVerifiedSaysProposed() {
        // Every field present but NONE verifies: localStatus (presence) would say honored/dissolved,
        // verifiedLocalStatus must say proposed.
        let p = make(
            counterpartyHonorSignature: "cp", counterpartyHonorTimestamp: ts,
            creatorHonorSignature: "cr", creatorHonorTimestamp: ts
        )
        #expect(p.localStatus == .honored)  // presence-based
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: [])) == .proposed)
    }

    @Test func testDissolvedRequiresValidDissolveSignature() {
        // A present-but-invalid dissolve must not win precedence over valid honors.
        let p = make(
            counterpartyHonorSignature: "cpHonor", counterpartyHonorTimestamp: ts,
            creatorHonorSignature: "crHonor", creatorHonorTimestamp: ts,
            creatorDissolveSignature: "forgedDissolve", creatorDissolveTimestamp: ts
        )
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["cpHonor", "crHonor"])) == .honored)
        // When the dissolve is valid, it takes precedence.
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["cpHonor", "crHonor", "forgedDissolve"])) == .dissolved)
    }

    @Test func testSignatureWithoutTimestampNotCounted() {
        let p = make(counterpartySignSignature: "sign", counterpartySignTimestamp: nil)
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["sign"])) == .proposed)
    }

    @Test func testPartedWhenOnePartValid() {
        let p = make(counterpartyPartSignature: "part", counterpartyPartTimestamp: ts)
        #expect(p.verifiedLocalStatus(verify: verifier(accepting: ["part"])) == .parted)
    }
}
