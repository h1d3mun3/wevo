//
//  ProposeExportImportRoundTripTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

/// Pins the invariant that makes an exported Propose re-importable: `createdAt` is the only
/// signed timestamp stored as a `Date` rather than a `String`, so it is the only one that makes a
/// round trip through a formatter on its way back into a signed message.
///
/// `ExportProposeUseCase` writes it with `ProposeAPIClient.iso8601String(from:)`, and
/// `ImportProposeUseCase.readFromFile` reads it back with `ProposeAPIClient.iso8601Date(from:)` —
/// but `verifyAllSignatures` does not use the file's text. It re-renders the decoded `Date` with
/// `iso8601String(from:)` and verifies the creator signature against *that*. So the creator
/// signature survives import only while
///
///     iso8601String(iso8601Date(iso8601String(d))) == iso8601String(d)
///
/// holds. Nothing in the production code states this dependency, and the two formatters behind
/// `iso8601Date` disagree about fractional seconds, so these tests state it instead.
struct ProposeExportImportRoundTripTests {

    // MARK: - Helpers

    private let space = Space(
        id: UUID(),
        name: "Test Space",
        url: "https://example.com",
        defaultIdentityID: nil,
        orderIndex: 0,
        createdAt: .now,
        updatedAt: .now
    )

    private func makePropose(createdAt: Date) -> Propose {
        Propose(
            id: UUID(),
            spaceID: UUID(),
            message: "Test message",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    /// The v1 creator message, built exactly as `ImportProposeUseCase.verifyAllSignatures` builds it.
    private func creatorMessage(for propose: Propose, createdAt: Date) -> String {
        "proposed."
            + propose.id.uuidString
            + propose.payloadHash
            + propose.creatorPublicKey
            + [propose.counterpartyPublicKey].sorted().joined()
            + ProposeAPIClient.iso8601String(from: createdAt)
    }

    private func makeImportUseCase(
        keychain: MockKeychainRepository
    ) -> ImportProposeUseCaseImpl {
        ImportProposeUseCaseImpl(
            proposeRepository: MockProposeRepository(),
            keychainRepository: keychain
        )
    }

    // MARK: - The round-trip invariant

    /// A sub-millisecond `createdAt` is the sharp case: `ISO8601DateFormatter` renders milliseconds,
    /// so export is lossy. What matters is not that the `Date` survives intact — it does not — but
    /// that re-rendering the *decoded* value reproduces the string the signature was computed over.
    @Test("Export/import preserves the rendered createdAt, even below millisecond precision")
    func roundTripPreservesRenderedCreatedAt() throws {
        let original = Date(timeIntervalSince1970: 1789624800.123456)
        let propose = makePropose(createdAt: original)

        let url = try ExportProposeUseCaseImpl().execute(propose: propose, space: space)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try makeImportUseCase(keychain: MockKeychainRepository()).readFromFile(url: url)

        #expect(
            ProposeAPIClient.iso8601String(from: imported.propose.createdAt)
                == ProposeAPIClient.iso8601String(from: original)
        )
    }

    /// The end-to-end statement of the same invariant: run the real `execute()` path and assert on
    /// the message it actually handed the verifier, rather than trusting that a decoded `Date`
    /// happens to be close enough.
    @Test("Import verifies the creator signature against the message the creator signed")
    func importVerifiesCreatorSignatureAgainstOriginalMessage() throws {
        let original = Date(timeIntervalSince1970: 1789624800.123456)
        let propose = makePropose(createdAt: original)

        let url = try ExportProposeUseCaseImpl().execute(propose: propose, space: space)
        defer { try? FileManager.default.removeItem(at: url) }

        let keychain = MockKeychainRepository()
        let useCase = makeImportUseCase(keychain: keychain)
        let imported = try useCase.readFromFile(url: url)
        try useCase.execute(propose: imported.propose, spaceID: imported.spaceID)

        // The creator signature is always verified first.
        #expect(
            keychain.verifySignatureCalledWithMessages.first
                == creatorMessage(for: propose, createdAt: original)
        )
    }

    // MARK: - Characterization: a timestamp this app has never written

    /// Every shipped version of the exporter has rendered `createdAt` *with* fractional seconds, so
    /// a file carrying a whole-second `createdAt` cannot have come from this app. `iso8601Date`
    /// still accepts it via its non-fractional fallback, and this test records what happens next:
    /// the re-rendered message gains a `.000`, so it no longer matches whatever was signed.
    ///
    /// This is a characterization test, not an endorsement. It has no effect on real files; it
    /// exists so that a future change to the export format — or a decision to accept foreign
    /// exports — fails here loudly instead of silently rejecting valid signatures.
    @Test("A whole-second createdAt re-renders with .000, changing the verified message")
    func wholeSecondCreatedAtRerendersWithMilliseconds() throws {
        let wholeSecond = Date(timeIntervalSince1970: 1789624800)
        let propose = makePropose(createdAt: wholeSecond)

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        let asWritten = basic.string(from: wholeSecond)
        #expect(asWritten == "2026-09-17T06:00:00Z")

        // Write the export by hand: the shipped exporter cannot produce this shape.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(basic.string(from: date))
        }
        let data = try encoder.encode(
            ProposeExportData(
                version: 1,
                propose: propose,
                spaceID: space.id,
                spaceName: space.name,
                exportedAt: wholeSecond
            )
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whole-second-\(propose.id.uuidString).wevo-propose")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let keychain = MockKeychainRepository()
        let useCase = makeImportUseCase(keychain: keychain)
        let imported = try useCase.readFromFile(url: url)
        try useCase.execute(propose: imported.propose, spaceID: imported.spaceID)

        let verified = try #require(keychain.verifySignatureCalledWithMessages.first)
        #expect(verified.hasSuffix("2026-09-17T06:00:00.000Z"))
        #expect(!verified.hasSuffix(asWritten))
    }
}
