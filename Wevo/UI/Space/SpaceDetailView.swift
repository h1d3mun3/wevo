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

    /// 進行中 / 完了済み の切り替えタブ
    @State private var selectedTab: ProposeTab = .active

    private enum ProposeTab: String, CaseIterable {
        case active = "進行中"
        case completed = "完了済み"
    }

    /// アクティブ（proposed / signed）なProposeのリスト
    private var activeProposes: [Propose] {
        proposes.filter { $0.localStatus.isActive }
    }

    /// 完了済み（honored / parted / dissolved）なProposeのリスト
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

            // SegmentedControl（進行中 / 完了済み）
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
                            ProposeRowView(propose: propose, space: space) {
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
            print("❌ デフォルトIdentityの読み込みエラー: \(error)")
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
                print("ℹ️ ローカルにProposeが見つかりません: \(currentSpace.name)")
            } else {
                print("✅ ローカルから\(loadedProposes.count)件のProposeを読み込みました")
            }
        } catch {
            print("❌ ローカルからのPropose読み込みエラー: \(error)")
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
                print("✅ Space再読み込み完了: \(updatedSpace.name)")
            } catch SpaceRepositoryError.spaceNotFound {
                dismiss()
            } catch {
                print("Space再読み込みに失敗: \(error)")
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
