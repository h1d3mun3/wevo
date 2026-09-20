//
//  VerifyProposeHashUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

struct VerifyProposeHashUseCaseTests {

    @Test func testReturnsTrueWhenHashMatches() {
        // Arrange
        let message = "test message"
        let correctHash = message.sha256HashedString
        let useCase = VerifyProposeHashUseCaseImpl()

        // Act
        let result = useCase.execute(message: message, payloadHash: correctHash)

        // Assert
        #expect(result == true)
    }

    @Test func testReturnsFalseWhenHashDoesNotMatch() {
        // Arrange
        let useCase = VerifyProposeHashUseCaseImpl()

        // Act
        let result = useCase.execute(message: "test message", payloadHash: "wrong-hash")

        // Assert
        #expect(result == false)
    }

    @Test func testReturnsFalseWhenMessageIsTampered() {
        // Arrange
        let originalMessage = "original message"
        let originalHash = originalMessage.sha256HashedString
        let useCase = VerifyProposeHashUseCaseImpl()

        // Act
        let result = useCase.execute(message: "tampered message", payloadHash: originalHash)

        // Assert
        #expect(result == false)
    }

    @Test func testReturnsTrueForEmptyMessage() {
        // Arrange
        let message = ""
        let correctHash = message.sha256HashedString
        let useCase = VerifyProposeHashUseCaseImpl()

        // Act
        let result = useCase.execute(message: message, payloadHash: correctHash)

        // Assert
        #expect(result == true)
    }
}
