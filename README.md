# Wevo

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Trust, in most services, is stored inside the service itself. Your ratings, your agreements, your track record — they live in someone else's database. When the service shuts down, or changes its rules, or you simply move on, that history disappears with it.

Wevo is an exploration of a different approach. Rather than computing a trust score, Wevo records *what happened*: proposals made, agreements reached, signatures given. Each event is cryptographically signed by the parties involved, stored locally on your device, and owned by you — not by a platform.

This repository is a **Swift reference implementation** of that idea, built for iOS and macOS. It is experimental and minimal.

→ For the problem statement, core ideas, and design philosophy behind Wevo, see [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space).

---

## What This Repository Is

This is the iOS/macOS client application, built with SwiftUI and SwiftData. It handles:

- Creating and managing cryptographic identities (P-256, stored in Keychain)
- Composing, signing, and verifying proposals (`Propose`)
- Organizing proposals into spaces (local contexts)
- Exporting and importing proposals, identities, and contacts via AirDrop and file sharing (`.wevo-propose`, `.wevo-identity`, `.wevo-contact`)
- Syncing with a WevoSpace server for multi-party coordination

This is one implementation of the Wevo approach. The underlying ideas — signed proposals, portable identities, locally-owned history — could be implemented on other platforms or in other languages.

## Current Status

**Experimental / Alpha.**

The core flows work: create an identity, write a proposal, sign it, share it. But:

- No formal data format specification exists yet; the schema may change without migration
- Server integration is partial and not resilient
- Automated test coverage is minimal
- This is not production-ready software

Use it to understand the approach, experiment with the ideas, or contribute to the direction.

## Design Notes

- Biometric authentication (Face ID / Touch ID) gates Keychain access where available, via `LAContext`
- Signatures use P-256 ECDSA (CryptoKit); public keys are represented as JWK (JSON Web Key) for interoperability with other implementations
- Public keys are displayed as a short fingerprint (SHA-256 of the raw key bytes, first 8 bytes as colon-separated hex, e.g. `AB:CD:EF:12:34:56:78:90`) rather than the raw key string
- Export formats (`.wevo-propose`, `.wevo-identity`, `.wevo-contact`) include a `version` field to support future format migrations
- SwiftData with optional CloudKit sync keeps data on-device by default
- File-based transfer (`.wevo-propose`, `.wevo-identity`, `.wevo-contact`) for peer-to-peer key exchange via AirDrop

## Getting Started

1. Open `Wevo.xcodeproj` in Xcode 15 or later.
2. Select the `Wevo` target (iOS or macOS).
3. Build and run on a simulator or device.

To use the app, add a Space with a WevoSpace server URL from within the app.

> **CloudKit sync** is enabled by default. To disable it, remove `cloudKitDatabase: .automatic` from the `ModelConfiguration` in `WevoApp.swift`.

### WevoSpace Server

The companion server handles proposal storage and multi-party synchronization:
→ [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space)

## Try it

TestFlight: https://testflight.apple.com/join/5SacJesr

## API / Documentation

- WevoSpace REST API (English): [`wevo-space/docs/PROPOSE_API.md`](https://github.com/h1d3mun3/wevo-space/blob/main/docs/PROPOSE_API.md)
- OpenAPI spec: [`wevo-space/api/`](https://github.com/h1d3mun3/wevo-space/tree/main/api)

---

*If this direction interests you — portable, verifiable history as a foundation for trust — feedback and contributions are welcome.*

---
---

# Wevo（日本語）

多くのサービスでは、信頼に関するデータ――評価、合意の記録、実績――はサービスの内部に閉じ込められています。そのサービスが終了したり、ルールが変わったり、あるいはただ使わなくなったりしたとき、その履歴は消えてしまいます。

Wevo は、そこへの別のアプローチを探るプロジェクトです。信頼をスコアとして計算するのではなく、*起きたこと* を記録します。提案、合意、署名。それぞれの出来事は関係者によって暗号学的に署名され、自分のデバイスにローカル保存され、プラットフォームではなく自分が所有します。

このリポジトリは、そのアイデアを Swift で実装した **reference implementation の一つ** です。iOS/macOS 向けです。実験的・最小限の実装です。

→ Wevo の問題提起・コアとなる考え方・設計思想については [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space) を参照してください。

---

## このリポジトリの位置づけ

これは SwiftUI と SwiftData で構築された iOS/macOS クライアントアプリです。以下を扱います：

- 暗号学的 Identity の作成・管理（P-256、Keychain に保存）
- Propose の作成・署名・検証
- Propose を Space（ローカルコンテキスト）で整理
- AirDrop やファイル共有による Propose・Identity・Contact のエクスポート/インポート（`.wevo-propose`、`.wevo-identity`、`.wevo-contact`）
- WevoSpace サーバーとの同期（マルチパーティ連携）

これは Wevo のアプローチを実装したものの一つです。署名付き提案、ポータブルな Identity、ローカル所有の履歴という考え方は、他のプラットフォームや言語でも実装できます。

## 現在の状態

**実験的 / Alpha。**

基本的なフローは動作します：Identity の作成、Propose の作成、署名、共有。ただし：

- データフォーマットの仕様はまだ確定していません。マイグレーションなしに変更される可能性があります
- サーバー連携は部分的で、堅牢ではありません
- 自動テストのカバレッジは最小限です
- プロダクション用途には対応していません

アプローチを理解する、アイデアを試してみる、方向性に貢献するために使ってください。

## 設計メモ

- Face ID / Touch ID（`LAContext` 経由）で Keychain アクセスを保護
- P-256 ECDSA 署名（CryptoKit）を使用。公開鍵は JWK（JSON Web Key）形式で表現され、他の実装との相互運用性を確保
- 公開鍵はUIに生の文字列ではなく、短いフィンガープリント（鍵バイト列の SHA-256 先頭8バイトをコロン区切り16進表示、例: `AB:CD:EF:12:34:56:78:90`）として表示
- エクスポートフォーマット（`.wevo-propose`、`.wevo-identity`、`.wevo-contact`）は将来のフォーマット移行に備えた `version` フィールドを含む
- SwiftData とオプションの CloudKit 同期でデータをデバイス上に保持
- ファイルベースの転送（`.wevo-propose`、`.wevo-identity`、`.wevo-contact`）でAirDrop経由のP2P鍵交換が可能

## Getting Started

1. Xcode 15 以降で `Wevo.xcodeproj` を開く
2. `Wevo` ターゲット（iOS または macOS）を選択
3. シミュレータまたは実機でビルド・実行

アプリ内で WevoSpace サーバー URL を指定した Space を追加してください。

> **CloudKit 同期** はデフォルトで有効です。不要な場合は `WevoApp.swift` の `ModelConfiguration` から `cloudKitDatabase: .automatic` を削除してください。

### WevoSpace サーバー

Propose の保存とマルチパーティ同期を扱うコンパニオンサーバー：
→ [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space)

## Try it

TestFlight: https://testflight.apple.com/join/5SacJesr

## API / ドキュメント

- WevoSpace REST API（英語）：[`wevo-space/docs/PROPOSE_API.md`](https://github.com/h1d3mun3/wevo-space/blob/main/docs/PROPOSE_API.md)
- OpenAPI 仕様：[`wevo-space/api/`](https://github.com/h1d3mun3/wevo-space/tree/main/api)

---

*ポータブルで検証可能な履歴を信頼の基盤にするという方向性に関心があれば、フィードバックや貢献を歓迎します。*
