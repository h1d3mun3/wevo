//
//  IdentityListView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct IdentityListView: View {
    @Environment(\.dependencies) private var deps

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
            print("❌ Error loading identities: \(error)")
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
