//
//  SpaceDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import os

// MARK: - Container

struct SpaceDetailView: View {
    let space: Space

    @Environment(\.dependencies) private var deps

    var body: some View {
        SpaceDetailContent(
            viewModel: SpaceDetailViewModel(space: space, deps: deps)
        )
    }
}

// MARK: - Content

private struct SpaceDetailContent: View {
    @State var viewModel: SpaceDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SpaceHeaderView(
                space: viewModel.currentSpace,
                defaultIdentity: viewModel.defaultIdentity,
                onEditTapped: { viewModel.shouldShowEditSpace = true }
            )

            Divider()

            Picker("", selection: $viewModel.selectedTab) {
                ForEach(SpaceDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading proposes...")
                    .progressViewStyle(.circular)
                Spacer()
            } else if let errorMessage = viewModel.errorMessage {
                Spacer()
                ProposeErrorView(
                    errorMessage: errorMessage,
                    onRetry: viewModel.loadProposesFromLocal
                )
                Spacer()
            } else {
                let displayProposes = viewModel.selectedTab == .active
                    ? viewModel.activeProposes
                    : viewModel.completedProposes

                if displayProposes.isEmpty {
                    Spacer()
                    EmptyProposeView(hasDefaultIdentity: viewModel.defaultIdentity != nil)
                    Spacer()
                } else {
                    List {
                        ForEach(displayProposes) { propose in
                            ProposeRowView(
                                propose: propose,
                                space: viewModel.currentSpace,
                                serverCheckTrigger: viewModel.serverCheckTrigger
                            ) {
                                viewModel.loadProposesFromLocal()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(viewModel.currentSpace.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.shouldShowCreatePropose = true
                } label: {
                    Label("Create Propose", systemImage: "plus")
                }
            }
        }
        .task {
            await viewModel.loadDefaultIdentity()
            viewModel.loadProposesFromLocal()
        }
        .refreshable {
            viewModel.refresh()
        }
        .onCloudKitImport {
            viewModel.loadProposesFromLocal()
            Task { await viewModel.reloadSpace() }
        }
        .sheet(isPresented: $viewModel.shouldShowCreatePropose) {
            CreateProposeView(space: viewModel.currentSpace) {
                Task {
                    viewModel.loadProposesFromLocal()
                }
            }
        }
        .sheet(isPresented: $viewModel.shouldShowEditSpace) {
            EditSpaceView(space: viewModel.currentSpace) {
                Task {
                    await viewModel.reloadSpace()
                }
            }
        }
        .onChange(of: viewModel.shouldDismiss) { _, should in
            if should { dismiss() }
        }
    }
}

// MARK: - Preview

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
