import Foundation

struct ProposeExportData: Codable {
    let version: Int
    let propose: Propose
    let spaceID: UUID
    let spaceName: String
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case version
        case propose
        case spaceID = "spaceId"
        case spaceName
        case exportedAt
    }
}
