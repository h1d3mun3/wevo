//
//  SpaceDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: Space

    @Environment(\.dependencies) private var deps

    @State private var proposes: [Propose] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var defaultIdentity: Identity?
    @State private var shouldShowCreatePropose = false
    @State private var shouldShowEditSpace = false
    @State private var currentSpace: Space

    init(space: Space) {
        self.space = space
        _currentSpace = State(initialValue: space)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SpaceHeaderView(
                space: currentSpace,
                defaultIdentity: defaultIdentity,
                onEditTapped: { shouldShowEditSpace = true }
            )

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading proposes...")
                    .progressViewStyle(.circular)
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                ProposeErrorView(
                    errorMessage: errorMessage,
                    onRetry: loadProposesFromLocal
                )
                Spacer()
            } else if proposes.isEmpty {
                Spacer()
                EmptyProposeView(hasDefaultIdentity: defaultIdentity != nil)
                Spacer()
            } else {
                List {
                    ForEach(proposes) { propose in
                        ProposeRowView(propose: propose, space: space) {
                            loadProposesFromLocal()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(currentSpace.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shouldShowCreatePropose = true
                } label: {
                    Label("Create Propose", systemImage: "plus")
                }
                .disabled(defaultIdentity == nil)
            }
        }
        .task(id: space.id) {
            await loadDefaultIdentity()
            loadProposesFromLocal()
        }
        .refreshable {
            loadProposesFromLocal()
        }
        .sheet(isPresented: $shouldShowCreatePropose) {
            if let identity = defaultIdentity {
                CreateProposeView(space: currentSpace, identity: identity) {
                    Task {
                        loadProposesFromLocal()
                    }
                }
            }
        }
        .sheet(isPresented: $shouldShowEditSpace) {
            EditSpaceView(space: currentSpace) {
                Task {
                    await reloadSpace()
                }
            }
        }
    }

    private func loadDefaultIdentity() async {
        guard let defaultIdentityID = space.defaultIdentityID else {
            await MainActor.run {
                self.defaultIdentity = nil
            }
            return
        }

        do {
            let getIdentityUseCase = GetIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
            self.defaultIdentity = try getIdentityUseCase.execute(id: defaultIdentityID)
        } catch {
            print("❌ Error loading default identity: \(error)")
            await MainActor.run {
                self.defaultIdentity = nil
            }
        }
    }

    private func loadProposesFromLocal() {
        isLoading = true
        errorMessage = nil

        do {
            let loadAllProposesUseCase = LoadAllProposesUseCaseIpml(proposeRepository: deps.proposeRepository)
            let loadedProposes = try loadAllProposesUseCase.execute(id: currentSpace.id)

            proposes = loadedProposes
            isLoading = false

            if loadedProposes.isEmpty {
                print("ℹ️ No proposes found locally for space: \(currentSpace.name)")
            } else {
                print("✅ Loaded \(loadedProposes.count) proposes from local storage")
            }
        } catch {
            print("❌ Error loading proposes from local storage: \(error)")
            isLoading = false
            errorMessage = "Failed to load proposes: \(error.localizedDescription)"
            proposes = []
        }
    }

    private func reloadSpace() async {
        await MainActor.run {
            let getSpaceUseCase = GetSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
            do {
                let updatedSpace = try getSpaceUseCase.execute(id: space.id)
                currentSpace = updatedSpace
                print("✅ Space reloaded: \(updatedSpace.name)")
            } catch {
                print("Failed to Reload Space: \(error)")
            }
        }
    }
}

#Preview("Space Detail") {
    let space = Space(
        id: UUID(),
        name: "Preview Space",
        url: "https://example.com",
        defaultIdentityID: nil,
        orderIndex: 0,
        createdAt: .now,
        updatedAt: .now
    )

    SpaceDetailView(space: space)
}
