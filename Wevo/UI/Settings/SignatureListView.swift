//
//  SignatureListView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct SignatureListView: View {
    let signatures: [SignatureSwiftData]
    @Environment(\.modelContext) private var modelContext

    @State private var signatureVerifications: [UUID: Bool] = [:]

    var onDelete: () -> Void = {}

    var body: some View {
        List {
            if signatures.isEmpty {
                Text("No signatures in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(signatures, id: \.id) { signature in
                    NavigationLink {
                        SignatureDetailView(signature: SignatureConverter.toEntity(from: signature))
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

    private func verifySignature(_ signature: SignatureSwiftData) async -> Bool {
        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: SignatureRepositoryImpl(modelContext: modelContext),
            keychainRepository: KeychainRepositoryImpl()
        )

        do {
            return try useCase.execute(
                signatureID: signature.id,
                signatureData: signature.signatureData,
                publicKey: signature.publicKey
            )
        } catch {
            print("❌ Error verifying signature \(signature.id): \(error)")
            return false
        }
    }

    private func deleteSignature(_ signature: SignatureSwiftData) {
        let useCase = DeleteSignatureUseCaseImpl(
            signatureRepository: SignatureRepositoryImpl(modelContext: modelContext)
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
    let signature = SignatureSwiftData(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signatureData: "PreviewSignatureData",
        createdAt: .now
    )

    SignatureListView(signatures: [signature])
        .modelContainer(for: [SpaceSwiftData.self, ProposeSwiftData.self, SignatureSwiftData.self], inMemory: true)
}
