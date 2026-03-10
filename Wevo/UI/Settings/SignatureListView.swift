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

    private func verifySignature(_ signature: SignatureSwiftData) async -> Bool {
        // 全てのProposeSwiftDataを取得して、署名が含まれているものを探す
        let descriptor = FetchDescriptor<ProposeSwiftData>()

        do {
            let allProposes = try modelContext.fetch(descriptor)

            // 署名が含まれているProposeを探す
            guard let propose = allProposes.first(where: { propose in
                (propose.signatures ?? []).contains(where: { $0.id == signature.id })
            }) else {
                print("⚠️ No propose found for signature: \(signature.id)")
                return false
            }

            let verifySignatureUseCase = VerifySignatureUseCaseImpl(keychainRepository: KeychainRepositoryImpl())

            let isValid = try verifySignatureUseCase.execute(
                signature: signature.signatureData,
                message: propose.payloadHash,
                publicKey: signature.publicKey
            )

            return isValid
        } catch {
            print("❌ Error verifying signature \(signature.id): \(error)")
            return false
        }
    }

    private func deleteSignature(_ signature: SignatureSwiftData) {
        modelContext.delete(signature)

        do {
            try modelContext.save()
            print("✅ Signature deleted: \(signature.id)")
            onDelete()
        } catch {
            print("❌ Error deleting signature: \(error)")
        }
    }
}
