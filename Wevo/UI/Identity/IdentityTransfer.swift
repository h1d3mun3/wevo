import Foundation

struct IdentityExportData: Codable {
    let version: Int
    let id: UUID
    let nickname: String
    let publicKey: String // JWK format
    let exportedAt: Date

    init(version: Int, id: UUID, nickname: String, publicKey: String, exportedAt: Date) {
        self.version = version
        self.id = id
        self.nickname = nickname
        self.publicKey = publicKey
        self.exportedAt = exportedAt
    }
}

enum IdentityTransfer {
    static func exportToFile(identity: Identity) throws -> URL {
        let exportData = IdentityExportData(
            version: 1,
            id: identity.id,
            nickname: identity.nickname,
            publicKey: identity.publicKey,
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(exportData)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "identity-\(exportData.id.uuidString).wevo-identity"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    static func importFromFile(url: URL) throws -> IdentityExportData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IdentityExportData.self, from: data)
    }
}
