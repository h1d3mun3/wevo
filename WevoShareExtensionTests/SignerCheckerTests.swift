//
//  SignerCheckerTests.swift
//  WevoShareExtensionTests
//

import Testing
@testable import WevoShareExtension

// MARK: - Mocks

private struct MockSelfKeyChecker: SelfKeyChecking {
    var result: Bool
    func isSelfPublicKey(rawBase64: String) throws -> Bool { result }
}

private struct MockContactChecker: ContactChecking {
    var result: Bool
    func isKnownContact(rawPublicKeyBase64: String) -> Bool { result }
}

private func makeChecker(isSelf: Bool, isContact: Bool) -> SignerChecker {
    SignerChecker(
        selfChecker: MockSelfKeyChecker(result: isSelf),
        contactChecker: MockContactChecker(result: isContact)
    )
}

// MARK: - Tests

struct SignerCheckerTests {

    @Test func testReturnsSelfSignedWhenSelfKeyMatches() {
        let checker = makeChecker(isSelf: true, isContact: false)
        #expect(checker.resolve(rawPublicKeyBase64: "key") == .selfSigned)
    }

    @Test func testReturnsKnownWhenContactMatches() {
        let checker = makeChecker(isSelf: false, isContact: true)
        #expect(checker.resolve(rawPublicKeyBase64: "key") == .known)
    }

    @Test func testReturnsUnknownWhenNoMatch() {
        let checker = makeChecker(isSelf: false, isContact: false)
        #expect(checker.resolve(rawPublicKeyBase64: "key") == .unknown)
    }

    @Test func testSelfSignedTakesPriorityOverKnown() {
        let checker = makeChecker(isSelf: true, isContact: true)
        #expect(checker.resolve(rawPublicKeyBase64: "key") == .selfSigned)
    }

    @Test func testSelfCheckerThrowingFallsThrough() {
        struct ThrowingSelfChecker: SelfKeyChecking {
            func isSelfPublicKey(rawBase64: String) throws -> Bool {
                throw KeychainAccessError.identityNotFound
            }
        }
        let checker = SignerChecker(
            selfChecker: ThrowingSelfChecker(),
            contactChecker: MockContactChecker(result: true)
        )
        #expect(checker.resolve(rawPublicKeyBase64: "key") == .known)
    }
}
