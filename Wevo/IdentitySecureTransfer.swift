import Foundation

struct IdentityPlainExport: Codable {
    let id: UUID
    let nickname: String
    let publicKey: String
    let privateKey: String
    let exportedAt: Date
}

enum IdentityPlainTransfer {
    static func exportPlainToFile(identity: Identity, privateKeyBase64: String) throws -> URL {
        let export = IdentityPlainExport(id: identity.id, nickname: identity.nickname, publicKey: identity.publicKey, privateKey: privateKeyBase64, exportedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let fileName = "identity-\(identity.id.uuidString).wevo-identity"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }

    static func importPlainFromFile(url: URL) throws -> IdentityPlainExport {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IdentityPlainExport.self, from: data)
    }
}
