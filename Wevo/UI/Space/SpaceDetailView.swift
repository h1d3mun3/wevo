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
    @Environment(\.dismiss) private var dismiss

    @State private var proposes: [Propose] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var defaultIdentity: Identity?
    @State private var shouldShowCreatePropose = false
    @State private var shouldShowEditSpace = false
    @State private var currentSpace: Space
    @State private var serverCheckTrigger = UUID()

    /// Tab for switching between active / completed
    @State private var selectedTab: ProposeTab = .active

    private enum ProposeTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
    }

    /// List of active (proposed / signed) Proposes
    private var activeProposes: [Propose] {
        proposes.filter { $0.localStatus.isActive }
    }

    /// List of completed (honored / parted / dissolved) Proposes
    private var completedProposes: [Propose] {
        proposes.filter { !$0.localStatus.isActive }
    }

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

            // SegmentedControl (Active / Completed)
            Picker("", selection: $selectedTab) {
                ForEach(ProposeTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

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
            } else {
                let displayProposes = selectedTab == .active ? activeProposes : completedProposes

                if displayProposes.isEmpty {
                    Spacer()
                    EmptyProposeView(hasDefaultIdentity: defaultIdentity != nil)
                    Spacer()
                } else {
                    List {
                        ForEach(displayProposes) { propose in
                            ProposeRowView(propose: propose, space: space, serverCheckTrigger: serverCheckTrigger) {
                                loadProposesFromLocal()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
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
            serverCheckTrigger = UUID()
        }
        .onCloudKitImport {
            loadProposesFromLocal()
            Task { await reloadSpace() }
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
            print("❌ Error loading default Identity: \(error)")
            await MainActor.run {
                self.defaultIdentity = nil
            }
        }
    }

    private func loadProposesFromLocal() {
        isLoading = true
        errorMessage = nil

        do {
            let loadAllProposesUseCase = LoadAllProposesUseCaseImpl(proposeRepository: deps.proposeRepository)
            let loadedProposes = try loadAllProposesUseCase.execute(id: currentSpace.id)

            proposes = loadedProposes
            isLoading = false

            if loadedProposes.isEmpty {
                print("ℹ️ No proposes found locally: \(currentSpace.name)")
            } else {
                print("✅ Loaded \(loadedProposes.count) propose(s) from local storage")
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
                print("✅ Space reload complete: \(updatedSpace.name)")
            } catch SpaceRepositoryError.spaceNotFound {
                dismiss()
            } catch {
                print("Failed to reload Space: \(error)")
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
