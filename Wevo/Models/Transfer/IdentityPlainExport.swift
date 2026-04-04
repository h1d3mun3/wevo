import Foundation

struct IdentityPlainExport: Codable {
    let id: UUID
    let nickname: String
    let publicKey: String
    let privateKey: String
    let exportedAt: Date
}
