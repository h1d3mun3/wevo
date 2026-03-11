//
//  SignatureListView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct SignatureListView: View {
    let signatures: [Signature]
    @Environment(\.dependencies) private var deps

    @State private var signatureVerifications: [UUID: Bool] = [:]

    var onDelete: () -> Void = {}

    var body: some View {
        List {
            if signatures.isEmpty {
                Text("No signatures in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(signatures) { signature in
                    NavigationLink {
                        SignatureDetailView(signature: signature)
                    } label: {
                        SignatureRowItemView(
                            signature: signature,
                            isValid: signatureVerifications[signature.id]
                        )
                    }
                    .task {
                        // 署名を検証
                        if signatureVerifications[signature.id] == nil {
                            let isValid = await verifySignature(signature)
                            await MainActor.run {
                                signatureVerifications[signature.id] = isValid
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let signature = signatures[index]
                        deleteSignature(signature)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func verifySignature(_ signature: Signature) async -> Bool {
        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: deps.signatureRepository,
            keychainRepository: deps.keychainRepository
        )

        do {
            return try useCase.execute(
                signatureID: signature.id,
                signatureData: signature.signature,
                publicKey: signature.publicKey
            )
        } catch {
            print("❌ Error verifying signature \(signature.id): \(error)")
            return false
        }
    }

    private func deleteSignature(_ signature: Signature) {
        let useCase = DeleteSignatureUseCaseImpl(
            signatureRepository: deps.signatureRepository
        )

        do {
            try useCase.execute(id: signature.id)
            onDelete()
        } catch {
            print("❌ Error deleting signature: \(error)")
        }
    }
}

#Preview("Signature List") {
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signature: "PreviewSignatureData",
        createdAt: .now
    )

    SignatureListView(signatures: [signature])
}
