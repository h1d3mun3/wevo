//
//  EditSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import os

// MARK: - Container

struct EditSpaceView: View {
    let space: Space
    let onUpdate: () -> Void

    @Environment(\.dependencies) private var deps

    var body: some View {
        EditSpaceContent(
            viewModel: EditSpaceViewModel(space: space, onUpdate: onUpdate, deps: deps)
        )
    }
}

// MARK: - Content

private struct EditSpaceContent: View {
    @State var viewModel: EditSpaceViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Space Name", text: $viewModel.name)
                }

                Section("Server URL") {
                    TextField("Server URL", text: $viewModel.url)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                }

                Section("Default Key") {
                    HStack {
                        if let identity = viewModel.selectedIdentity {
                            Text(identity.nickname)
                                .font(.body)
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Change") { viewModel.showIdentityPicker = true }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Edit Space")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.saveChanges() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .disabled(viewModel.isSaving)
            .sheet(isPresented: $viewModel.showIdentityPicker) {
                IdentityPickerSheet(
                    identities: viewModel.identities,
                    selectedIdentity: $viewModel.selectedIdentity
                )
            }
            .task {
                viewModel.loadIdentities()
            }
            .onChange(of: viewModel.shouldDismiss) { _, should in
                if should { dismiss() }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 450)
#endif
    }
}

// MARK: - Preview

#Preview {
    EditSpaceView(
        space: Space(
            id: UUID(),
            name: "Example Space",
            url: "https://api.example.com",
            defaultIdentityID: UUID(),
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        ),
        onUpdate: {}
    )
}
