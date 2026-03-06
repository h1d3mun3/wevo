//
//  ProposeImportView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProposeImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var isImporting = false
    @State private var importedPropose: ProposeExportData?
    @State private var errorMessage: String?
    @State private var targetSpace: Space?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let importedPropose = importedPropose {
                    // インポート成功
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        Text("Propose Imported")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "From Space", value: importedPropose.spaceName)
                            InfoRow(label: "Payload Hash", value: importedPropose.propose.payloadHash)
                            InfoRow(label: "Signatures", value: "\(importedPropose.propose.signatures.count)")
                            InfoRow(label: "Exported At", value: importedPropose.exportedAt.formatted())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        if let targetSpace = targetSpace {
                            Text("Saved to: \(targetSpace.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                } else if let errorMessage = errorMessage {
                    // エラー
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)
                        
                        Text("Import Failed")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                } else {
                    // ファイル選択待ち
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Import Propose")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select a propose JSON file to import")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Choose File") {
                            isImporting = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Import Propose")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "No file selected"
                return
            }
            
            importPropose(from: url)
            
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }
    
    private func importPropose(from url: URL) {
        do {
            // JSONファイルを読み込み
            let exportData = try ProposeExporter.importPropose(from: url)
            
            // 対応するSpaceを探す
            let spaceRepository = SpaceRepository(modelContext: modelContext)
            let spaces = try spaceRepository.fetchAll()
            
            // Space IDが一致するSpaceを探す
            if let matchingSpace = spaces.first(where: { $0.id == exportData.spaceID }) {
                targetSpace = matchingSpace
                
                // SwiftDataに保存
                let proposeRepository = ProposeRepository(modelContext: modelContext)
                try proposeRepository.create(exportData.propose, spaceID: matchingSpace.id)
                
                importedPropose = exportData
                errorMessage = nil
                
                print("✅ Propose imported successfully to space: \(matchingSpace.name)")
            } else {
                // Space IDが一致しない場合、最初のSpaceに保存
                if let firstSpace = spaces.first {
                    targetSpace = firstSpace
                    
                    let proposeRepository = ProposeRepository(modelContext: modelContext)
                    try proposeRepository.create(exportData.propose, spaceID: firstSpace.id)
                    
                    importedPropose = exportData
                    errorMessage = nil
                    
                    print("⚠️ Original space not found. Saved to: \(firstSpace.name)")
                } else {
                    errorMessage = "No spaces found. Please create a space first."
                }
            }
            
        } catch {
            print("❌ Error importing propose: \(error)")
            errorMessage = "Failed to import propose: \(error.localizedDescription)"
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Preview

#Preview {
    ProposeImportView()
}
