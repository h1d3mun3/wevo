# Wevo

Wevo は、SwiftUI + SwiftData を使ったクロスプラットフォーム（iOS/macOS）アプリで、**公開鍵や署名付きメッセージ（Propose）を管理し、WevoSpace サーバーと同期する**ことに特化しています。

## 主要な特徴
- **アイデンティティ管理**: P256 鍵ペアを Keychain に保存し、ニックネーム変更・削除・インポート・エクスポート・マイグレーションにも対応。`IdentityListView` → `IdentityDetailView` で状態を確認し、`CreateIdentityUseCase` / `KeychainRepository` で新しい鍵を生成・保存します。
- **Space（サーバー）管理**: `AddSpaceView` / `EditSpaceView` からサーバー URL とデフォルトのアイデンティティを紐づけ、SwiftData で持つ `Space` エンティティ（`SpaceSwiftData`）としてローカル永続化します。
- **Propose の生成・確認・共有**: `CreateProposeView` はメッセージをハッシュ化(`String+Extensions`)して `Propose` を作り、署名は `KeychainRepository.signMessage` で付与。`ProposeAPIClient` で `.wevo-propose`（`UTType.wevoPropose`）ファイルをサーバーに送信し、`ProposeRowView` では再送・署名の同期・サーバー存在確認・共有(Safari/ShareSheet/AirDrop)・ローカル署名表示 を行います。
- **ファイルインポート/エクスポート**: `.wevo-propose` と `.wevo-identity` を `WevoApp` の `onOpenURL` で受け取り、`SpaceSelectorView` / `IdentityImportView` でインポート。`ProposeExporter` / `IdentityPlainTransfer` は JSON 出力（`ProposeExportData` / `IdentityPlainExport`）と専用拡張子の作成を扱い、`ShareSheetView` 経由で外部に渡せます。
- **デバッグ & 検証**: `SettingsView` では SwiftData に入っている Propose・Signature・Space を一覧表示し、`ProposeSettingsDetailView` がハッシュと署名の検証（`VerifySignatureUseCase`）を実施。`SignatureDetailView` からは個別の公開鍵とデータも確認できます。

## アーキテクチャとデータフロー
1. `WevoApp` で `ModelContainer` を `SpaceSwiftData`/`ProposeSwiftData`/`SignatureSwiftData` で構成し、必要に応じて CloudKit 同期を有効化。
2. `Repository`（Space/Propose/Keychain）は `SwiftData` をラップし、UseCase 層 (`GetAllSpacesUseCase` など) から呼び出されて CRUD を保証。
3. `CreateProposeUseCase` はメッセージのハッシュ化、署名、ローカル保存（`ProposeRepository`）、さらに `ProposeAPIClient` を使ったサーバー送信を連携。エラーが出てもローカルは維持される。
4. `ProposeRowView` はサーバー状態チェック (`ProposeAPIClient.getPropose`) を周期的に行い、新旧の署名リストを比較して同期・送信・再送をトリガー。
5. サーバーから受け取った署名は `AppendServerSignaturesToLocalProposeUseCase` で追記、ローカルからの未送信署名は `SignProposeUseCase` / `sendLocalSignaturesToServer` で API に再送。

## セキュリティと署名
- 公開鍵/秘密鍵は `KeychainRepository` 内で `P256.Signing.PrivateKey` を生成し、メタデータと秘密鍵をそれぞれ `.synchronizable` な `kSecClassGenericPassword` に保存。`LAContext` を渡すことでバイオ認証の保護も可能。
- `VerifySignatureUseCase` で、`CryptoKit` の P256 署名検証を再利用し、Settings 側でハッシュや署名の整合性を確認。
- `IdentityPlainTransfer` は鍵情報（Base64）のプレーンエクスポート/インポートを提供し、必要であれば既存鍵の上書きもサポート。

## UI の構成
- `ContentView` は `NavigationSplitView`（macOS/iPad）や `NavigationStack`（iOS）で `Space` 一覧、設定、アイデンティティ、スペース追加のシートを呼び出す。
- `SpaceDetailView` では選択したスペース内の Propose 一覧を表示し、Signature のステータス、クラウドとの同期、署名実行、共有を行う。`ProposeRowView` の詳細画面（`ProposeDetailView` → `ProposeSettingsDetailView`）で署名の検証とメタ情報の把握が可能。
- `Identity` 周りは `IdentityListView` / `IdentityDetailView` を使ってコピー・編集・マイグレーション・共有・削除でき、`CreateIdentityView` で新しい鍵を作る。

## 実行と開発のヒント
1. Xcode 15 以降で `Wevo.xcodeproj` を開き、`Wevo` ターゲット（iOS/macOS）を選択。`WevoApp` に `ModelContainer` を持たせているため、実機もしくはシミュレータで SwiftData のモデルが自動的に作成されます。
2. `WevoApp` の `ModelContainer` は CloudKit 同期を `.automatic` に設定しているので、不要なら `ModelConfiguration` から `cloudKitDatabase` を取り除くか、Sandbox で Apple ID を確認してください。
3. `UTType.wevoPropose`/`UTType.wevoIdentity`（`WevoProposeDocument.swift`）は Info.plist の `Exported Type UTIs` セクションで `com.h1d3mun3.Wevo.propose` などを登録し、AirDrop/ShareSheet からのファイル受信を許可します。
4. `ProposeAPIClient` の `baseURL` は `Space.url`（例: `https://api.example.com`）から構築。ローカルで API サーバーを用意する際はエンドポイント `/proposes` を確認し、`createPropose`・`updatePropose`・`getPropose` などに対応すること。

## 追加リソース
- `WevoTests` / `WevoUITests` にテストコードを追加することで、Keychain 操作や `ProposeRowView` の状態遷移を自動化可能。
- `Resources` や `Assets.xcassets` に色・画像を追加すると、UI のブランディングと `ShareSheet` 表示が改善されます。
- `IdentitySecureTransfer.swift` / `ProposeExporter.swift` のログ(`print`)を通じてデバッグし、AirDrop 受信時の `handleIncomingURL` の流れが意図通りか確認してください。

## まとめ
Wevo は P256 鍵、SwiftData、HTTP API、ファイル共有を統合して「署名付きメッセージ」ライフサイクルを完結させるアプリです。Identity の鍵管理・Space のサーバー設定・Propose のローカル保持と同期・ファイル共有を README の説明に従って追跡することで、開発と運用をスムーズに進められます。
