//
//  WevoProposeDocument.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation
import UniformTypeIdentifiers

/// Wevo Proposeファイルのカスタム UTType
/// 
/// 命名規則: {Bundle ID}.{ドキュメントタイプ}
/// 例: Bundle ID が com.example.wevo の場合
///     UTI は com.example.wevo.propose
extension UTType {
    /// Wevo Propose ファイル (.wevo-propose)
    /// 
    /// ⚠️ 重要: Info.plistでUTTypeIdentifierを設定する際は、
    /// アプリのBundle IDに合わせて変更してください
    /// 
    /// 例: Bundle ID が com.example.wevo の場合
    ///     → "com.example.wevo.propose" に変更
    /// 
    /// 現在の設定: "com.h1d3mun3.Wevo.propose"
    static let wevoPropose = UTType(exportedAs: "com.h1d3mun3.Wevo.propose")
}

