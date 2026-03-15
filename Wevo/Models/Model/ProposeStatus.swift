//
//  ProposeStatus.swift
//  Wevo
//
//  Created by hidemune on 3/15/26.
//

import Foundation

/// Proposeの状態を表すenum
enum ProposeStatus: String, Codable {
    case proposed
    case signed
    case honored
    case parted
    case dissolved

    /// アクティブ（進行中）な状態かどうか
    var isActive: Bool {
        self == .proposed || self == .signed
    }
}
