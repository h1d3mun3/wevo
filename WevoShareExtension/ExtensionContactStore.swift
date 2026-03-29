//
//  ExtensionContactStore.swift
//  WevoShareExtension
//

import Foundation
import SwiftData
import CryptoKit

final class ExtensionContactStore {
    private static let appGroupIdentifier = "group.com.h1d3mun3.Wevo"
    private let container: ModelContainer?

    init() {
        let schema = Schema([
            SpaceSwiftData.self,
            ProposeSwiftData.self,
            ContactSwiftData.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: false,
            groupContainer: .identifier(Self.appGroupIdentifier)
        )
        self.container = try? ModelContainer(for: schema, configurations: [config])
    }

    /// Returns true if the raw base64 public key matches any stored contact.
    func isKnownContact(rawPublicKeyBase64: String) -> Bool {
        guard let container,
              let pkData = Data(base64Encoded: rawPublicKeyBase64),
              pkData.count == 64,
              let targetKey = try? P256.Signing.PublicKey(rawRepresentation: pkData)
        else { return false }

        let context = ModelContext(container)
        guard let contacts = try? context.fetch(FetchDescriptor<ContactSwiftData>()) else { return false }

        return contacts.contains { contact in
            guard let contactKey = P256.Signing.PublicKey(jwkString: contact.publicKey) else { return false }
            return contactKey.rawRepresentation == targetKey.rawRepresentation
        }
    }
}
