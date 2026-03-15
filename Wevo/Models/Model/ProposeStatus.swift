//
//  ProposeStatus.swift
//  Wevo
//
//  Created by hidemune on 3/15/26.
//

import Foundation

/// Enum representing the state of a Propose
enum ProposeStatus: String, Codable {
    case proposed
    case signed
    case honored
    case parted
    case dissolved

    /// Whether the state is active (in progress)
    var isActive: Bool {
        self == .proposed || self == .signed
    }
}
