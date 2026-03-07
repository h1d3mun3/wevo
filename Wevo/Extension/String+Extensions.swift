//
//  String+Extensions.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import CryptoKit

extension String {
    var sha256HashedString: Self {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
