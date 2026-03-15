//
//  WevoProposeDocument.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import UniformTypeIdentifiers

/// Custom UTType for Wevo Propose files
///
/// Naming convention: {Bundle ID}.{document type}
/// Example: if Bundle ID is com.example.wevo
///     UTI is com.example.wevo.propose
extension UTType {
    /// Wevo Propose file (.wevo-propose)
    ///
    /// ⚠️ Important: When setting UTTypeIdentifier in Info.plist,
    /// change it to match the app's Bundle ID
    ///
    /// Example: if Bundle ID is com.example.wevo
    ///     → change to "com.example.wevo.propose"
    ///
    /// Current setting: "com.h1d3mun3.Wevo.propose"
    static let wevoPropose = UTType(exportedAs: "com.h1d3mun3.Wevo.propose")
}

