//
//  ProposeExporter.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import UniformTypeIdentifiers

/// ProposeをエクスポートするためのWrapper
struct ProposeExportData: Codable {
    let propose: Propose
    let spaceID: UUID
    let spaceName: String
    let exportedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case propose
        case spaceID = "spaceId"
        case spaceName = "spaceName"
        case exportedAt = "exportedAt"
    }
}

/// ProposeのエクスポートとAirDrop共有を管理
struct ProposeExporter {
    
    /// ProposeをJSON形式でエクスポートし、共有可能なURLを返す
    static func exportPropose(_ propose: Propose, space: Space) throws -> URL {
        let exportData = ProposeExportData(
            propose: propose,
            spaceID: space.id,
            spaceName: space.name,
            exportedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(exportData)
        
        // 一時ディレクトリにファイルを保存
        let fileName = "propose-\(propose.id.uuidString).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try jsonData.write(to: tempURL)
        
        print("✅ Propose exported to: \(tempURL.path)")
        
        return tempURL
    }
    
    /// JSONファイルからProposeをインポート
    static func importPropose(from url: URL) throws -> ProposeExportData {
        let jsonData = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportData = try decoder.decode(ProposeExportData.self, from: jsonData)
        
        print("✅ Propose imported from: \(url.path)")
        
        return exportData
    }
}

/// AirDropでの共有をサポートするためのTransferable実装
@available(iOS 16.0, macOS 13.0, *)
extension ProposeExportData: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
