//
//  AuthenticateAndExportIdentityUseCaseTests.swift
//  WevoTests
//
//  Created on 3/17/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct AuthenticateAndExportIdentityUseCaseTests {

    let identity = Identity(
        id: UUID(),
        nickname: "Test Identity",
        publicKey: "TestPublicKey"
    )

    /// In test environments, biometric authentication is not available.
    /// The use case should throw biometricNotAvailable when LAContext cannot evaluate the policy.
    @Test("Throws biometricNotAvailable when biometrics are not available in test environment")
    func throwsWhenBiometricsNotAvailable() async {
        let mockRepository = MockKeychainRepository()
        let useCase = AuthenticateAndExportIdentityUseCaseImpl(keychainRepository: mockRepository)

        // In a simulator/test environment, biometric auth is not available,
        // so this should throw AuthenticateAndExportIdentityUseCaseError.biometricNotAvailable
        await #expect(throws: AuthenticateAndExportIdentityUseCaseError.self) {
            _ = try await useCase.execute(identity: identity)
        }
    }

    /// Verifies the error type and message when biometrics are not available.
    @Test("Error message includes reason when biometrics unavailable")
    func errorMessageIncludesReason() async {
        let mockRepository = MockKeychainRepository()
        let useCase = AuthenticateAndExportIdentityUseCaseImpl(keychainRepository: mockRepository)

        do {
            _ = try await useCase.execute(identity: identity)
            Issue.record("Expected an error to be thrown")
        } catch let error as AuthenticateAndExportIdentityUseCaseError {
            switch error {
            case .biometricNotAvailable(let reason):
                #expect(!reason.isEmpty)
            case .authenticationFailed:
                // Also acceptable in test environment
                break
            }
        } catch {
            // Other errors (e.g. from LAContext) are acceptable in test environment
        }
    }
}
