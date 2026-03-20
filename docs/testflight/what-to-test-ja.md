# テスト内容 — wevo TestFlight Beta

## 概要

wevo は P256 ECDSA 署名を使って、2者間の合意を暗号学的に記録するiOSアプリです。
署名はすべてデバイス上のKeychainで完結します。サーバー（wevo-space）はオプションの同期レイヤーです。

---

## はじめる前に

- **2台以上のiOSデバイスを推奨**（署名フローの全体を試すために必要）
- Face ID または Touch ID が有効であること（Identityのエクスポートに必要）
- サーバー同期を試す場合は wevo-space の URL が必要（別途共有）
- サーバーなしでもアプリはすべてオフラインで動作します

---

## 試してほしいフロー

### 1. Identityを作成する

**Manage Keys → + → ニックネームを入力 → Create**

- Identityがフィンガープリントとともに一覧に表示されることを確認
- 複数のIdentityを作成してみる

### 2. Spaceを作成する

**サイドバーの + → 名前とサーバーURL入力 → Add**

- Spaceがサイドバーに表示されることを確認
- URLを省略した場合（ローカルのみモード）も試す

### 3. AirDropでContactを交換する

**【デバイスA】** Manage Keys → Identityをタップ → Share as Contact → AirDropでデバイスBに送信

**【デバイスB】** `.wevo-contact` を受け取る → Contacts一覧に表示されることを確認

- 両デバイスのフィンガープリントが一致することを別の手段（口頭・Slack等）で確認

### 4. Proposeを作成して送る

**【デバイスA】** Spaceを開く → Create Propose → Identity・相手のContact・メッセージを入力 → Create → Export → AirDropで `.wevo-propose` をデバイスBに送信

- ステータスが `proposed` になることを確認
- メッセージ本文がローカルに保存されていることを確認

### 5. Proposeに署名する

**【デバイスB】** `.wevo-propose` を受け取る → Spaceを選択 → Proposeをタップ → Sign → Identityを選択

- Creatorが指定したCounterpartyの公開鍵と一致するIdentityのみ表示されることを確認
- ステータスが `signed` になることを確認

### 6. Honor / Part

**どちらかのデバイス** → Proposeをタップ → Honor（または Part）

- ProposeがCompletedタブに移動することを確認
- URLが設定されている場合、サーバーへの同期が行われることを確認

### 7. Identityのエクスポート / インポート

Manage Keys → Identityをタップ → Export → Face ID/Touch IDで認証 → `.wevo-identity` をAirDropで送信

- 生体認証が必要なことを確認
- 受け取り側でIdentityが正しく復元されることを確認

---

## 特に注目してほしい点

- `.wevo-propose` / `.wevo-identity` / `.wevo-contact` のAirDrop動作の安定性
- 署名時のIdentityフィルタリング（正しいCounterpartyのみ表示されるか）
- サーバーURLが無効・未到達の場合の挙動（ローカル保存が維持されるか）
- 同じApple IDを使う複数デバイス間のiCloud同期

---

## 既知の制限事項

- Counterpartyは1名のみ（現バージョンは2者間のみ対応）
- `.wevo-propose` ファイルを削除するとメッセージ本文は復元不可（サーバーにはハッシュのみ）
- このBetaビルドではHTTP接続が許可されている（本番リリースまでにHTTPS必須化予定）
- Beta期間中のSwiftDataスキーマ変更によりローカルデータがリセットされる可能性がある

---

## フィードバックの送り方

**TestFlightのフィードバック機能**を使ってください（デバイスを振るか、TestFlightアプリのフィードバックボタンから送信）。
バグ報告の際は再現手順・デバイスモデル・iOSバージョンを記載してもらえると助かります。
