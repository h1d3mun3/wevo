# テスト内容 — wevo TestFlight Beta

wevo はP256 ECDSA署名を使って2者間の合意をデバイス上で記録するアプリです。

【基本フロー（2台推奨）】
1. Identityを作成：Manage Keys → +
2. Spaceを作成：サイドバー +
3. IdentityをContactとしてAirDropで交換
4. Proposeを作成 → Export → AirDropで相手に送信
5. 受け取り側がインポート → Sign → Identityを選択
6. 双方でHonor（完了）またはPart（離脱）して確定

ステップ5の前（proposed状態中）はいずれかの参加者がDissolveでキャンセルすることもできます。

Identityエクスポートには生体認証が必要。本文はローカルのみ保存。
