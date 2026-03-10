//
//  IdentityListView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct IdentityListView: View {
    @State private var shouldShowCreateIdentity = false
    @State private var identities: [Identity] = []

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
    }
    
    private func loadIdentities() async {
        let getAllIdentityUseCase = GetAllIdentitiesUseCaseImpl(keychainRepository: KeychainRepositoryImpl())
        do {
            let loadedIdentities = try getAllIdentityUseCase.execute()
            await MainActor.run {
                identities = loadedIdentities
            }
        } catch {
            print("❌ Error loading identities: \(error)")
            await MainActor.run {
                identities = []
            }
        }
    }
    
    private func deleteIdentities(offsets: IndexSet) {
        let deleteIdentityUseCase = DeleteIdentityUseCaseImpl(keychainRepository: KeychainRepositoryImpl())
        Task {
            do {
                for index in offsets {
                    let identity = identities[index]
                    try deleteIdentityUseCase.execute(id: identity.id)
                }
                await loadIdentities()
            } catch {
                print("❌ Error deleting identity: \(error)")
                // TODO: エラーをユーザーに表示
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
