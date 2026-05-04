//
//  AddSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import os

// MARK: - Container

struct AddSpaceView: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        AddSpaceContent(viewModel: AddSpaceViewModel(deps: deps))
    }
}

// MARK: - Content

private struct AddSpaceContent: View {
    @State var viewModel: AddSpaceViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Space Name") {
                    TextField("Space Name", text: $viewModel.name)
                }

                Section("Space URL") {
                    TextField("Space URL", text: $viewModel.urlString)
                }

                Section("Default Identity") {
                    if viewModel.identities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No identities available")
                                .foregroundStyle(.secondary)
                            Text("Create an identity first to add a space.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Default Identity", selection: $viewModel.selectedIdentityID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(viewModel.identities) { identity in
                                Text(identity.nickname).tag(identity.id as UUID?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Space") {
                        Task { await viewModel.add() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task {
                await viewModel.loadIdentities()
            }
            .onChange(of: viewModel.shouldDismiss) { _, should in
                if should { dismiss() }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "")
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 450)
#endif
    }
}

// MARK: - Preview

#Preview {
    AddSpaceView()
}
