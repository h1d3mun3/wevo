//
//  IdentityListView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import os

struct IdentityListView: View {
    @Environment(\.dependencies) private var deps

    @State private var shouldShowCreateIdentity = false
    @State private var identities: [Identity] = []
    @State private var deleteIdentityError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(identities) { item in
                    NavigationLink {
                        IdentityDetailView(identity: item)
                    } label: {
                        Text(item.nickname)
                    }
                }
                .onDelete(perform: deleteIdentities)

                Button(action: { shouldShowCreateIdentity = true }) {
                    Text("Create Identity")
                }
            }
            .navigationTitle("Identity")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
            }
            .task {
                await loadIdentities()
            }
        }
        .sheet(isPresented: $shouldShowCreateIdentity, onDismiss: {
            Task {
                await loadIdentities()
            }
        }) {
            CreateIdentityView()
        }
        .alert("Error", isPresented: .init(
            get: { deleteIdentityError != nil },
            set: { if !$0 { deleteIdentityError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteIdentityError ?? "")
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
#endif
    }
    
    private func loadIdentities() async {
        let getAllIdentityUseCase = GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let loadedIdentities = try getAllIdentityUseCase.execute()
            await MainActor.run {
                identities = loadedIdentities
            }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
            await MainActor.run {
                identities = []
            }
        }
    }
    
    private func deleteIdentities(offsets: IndexSet) {
        let deleteIdentityUseCase = DeleteIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
        Task {
            do {
                for index in offsets {
                    let identity = identities[index]
                    try deleteIdentityUseCase.execute(id: identity.id)
                }
                await loadIdentities()
            } catch {
                Logger.identity.error("Error deleting identity: \(error, privacy: .public)")
                await MainActor.run {
                    deleteIdentityError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    IdentityListView()
}

#Preview {
    IdentityListView()
}
