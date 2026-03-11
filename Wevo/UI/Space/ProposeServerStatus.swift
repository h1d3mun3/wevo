//
//  ProposeServerStatus.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

enum ProposeServerStatus: Equatable {
    case unknown
    case checking
    case exists
    case notFound
    case error(String)

    var icon: String {
        switch self {
        case .unknown: return "circle"
        case .checking: return "circle.dotted"
        case .exists: return "checkmark.circle.fill"
        case .notFound: return "xmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .checking: return .blue
        case .exists: return .green
        case .notFound: return .orange
        case .error: return .red
        }
    }

    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .checking: return "Checking..."
        case .exists: return "On server"
        case .notFound: return "Not on server"
        case .error(let message): return "Error: \(message)"
        }
    }
}
