import Foundation

struct ContactExportData: Codable {
    let version: Int
    let publicKey: String // JWK format
    let exportedAt: Date
}
