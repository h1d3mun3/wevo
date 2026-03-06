//
//  KeychainItemConverter.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation

/// KeychainアイテムとドメインモデルのConverter
struct KeychainItemConverter {
    
    /// IdentityMetadataKeychainItemをIdentityに変換
    static func toIdentity(from keychainItem: IdentityMetadataKeychainItem) -> Identity {
        Identity(id: keychainItem.id, nickname: keychainItem.nickname)
    }
    
    /// IdentityMetadataKeychainItemの配列をIdentityの配列に変換
    static func toIdentities(from keychainItems: [IdentityMetadataKeychainItem]) -> [Identity] {
        keychainItems.map { toIdentity(from: $0) }
    }
}
