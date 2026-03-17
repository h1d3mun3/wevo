//
//  AuthenticateAndExportIdentityUseCase.swift
//  Wevo
//
//  Created on 3/17/26.
//

import Foundation
import LocalAuthentication

enum AuthenticateAndExportIdentityUseCaseError: Error, LocalizedError {
    case biometricNotAvailable(String)
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable(let reason):
            return "Biometric authentication not available: \(reason)"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

protocol AuthenticateAndExportIdentityUseCase {
    /// Performs biometric authentication and, on success, exports the identity as a file URL
    func execute(identity: Identity) async throws -> URL
}

struct AuthenticateAndExportIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension AuthenticateAndExportIdentityUseCaseImpl: AuthenticateAndExportIdentityUseCase {
    func execute(identity: Identity) async throws -> URL {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthenticateAndExportIdentityUseCaseError.biometricNotAvailable(
                error?.localizedDescription ?? "Unknown"
            )
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to export private key"
        )
        guard success else {
            throw AuthenticateAndExportIdentityUseCaseError.authenticationFailed
        }

        let exportUseCase = ExportIdentityUseCaseImpl(keychainRepository: keychainRepository)
        return try exportUseCase.execute(identity: identity)
    }
}
