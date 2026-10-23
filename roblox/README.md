# 🏮 わたしの旅館（Roblox 旅館経営ゲーム）

お客様をフロントでチェックインし、お茶・お料理・お布団のお願いに応えて旅館を大きくしていくゲームです。
マップ（建物・客室・鳥居・露天風呂）はスクリプトが自動で組み立てるので、Studio でのモデリングは不要です。

## 遊び方

1. **フロント**でお客様を「チェックイン」 → 空いている客室へ歩いていきます
2. 部屋でお客様がお願いをします（頭の上に吹き出しが出ます）
   - 🍵 **お茶** … 給湯室（右側）で受け取り、部屋の座卓まで運ぶ
   - 🍱 **お料理** … 厨房（左側）で受け取り、部屋の座卓まで運ぶ
   - 🛏️ **お布団** … 部屋の座卓で長押し
3. 早く応えるほどチップが増え、満足度が上がります
4. チェックアウト時に満足度に応じた宿泊料と ★ 評価がもらえます
5. 評判（★）が上がると、お客様の来る間隔が短くなります
6. お金がたまったら、玄関の内側にある掲示板で**客室を増築**（最大 6 部屋）

所持金と客室数は DataStore に保存されます。

## Studio への入れ方

### 方法 A：コピー＆ペースト（かんたん）

1. Roblox Studio で **Baseplate** テンプレートを開く
2. 次の構成でスクリプトを作り、各ファイルの中身を貼り付ける

| 場所 | 種類 | 名前 | 中身 |
|---|---|---|---|
| ReplicatedStorage | **Folder** | `Shared` | — |
| ReplicatedStorage › Shared | ModuleScript | `Config` | `src/shared/Config.luau` |
| ServerScriptService | Script | `Main` | `src/server/Main.server.luau` |
| ServerScriptService | ModuleScript | `WorldBuilder` | `src/server/WorldBuilder.luau` |
| ServerScriptService | ModuleScript | `DataManager` | `src/server/DataManager.luau` |
| ServerScriptService | ModuleScript | `GuestManager` | `src/server/GuestManager.luau` |
| StarterPlayer › StarterPlayerScripts | LocalScript | `HUD` | `src/client/HUD.client.luau` |

名前は大文字・小文字も含めて表のとおりにしてください（スクリプト同士が名前で読み込み合っています）。

3. ▶ **プレイ** で開始

### 方法 B：Rojo（ファイルで管理したい人向け）

```bash
cd roblox
rojo serve
```

Studio の Rojo プラグインで **Connect** すると、`default.project.json` のとおりに同期されます。

### データ保存を Studio で試すには

**ファイル › ゲーム設定 › セキュリティ › 「API サービスへの Studio アクセスを有効にする」** をオンにします。
オフのままでも遊べますが、所持金は保存されません（出力ウィンドウに警告が出ます）。

## カスタマイズ

バランス調整は `src/shared/Config.luau` の数値を変えるだけでできます。

- `RoomPrices` … 増築費用
- `RoomRate` … 基本の宿泊料
- `RequestPatience` … お客様が待ってくれる秒数
- `Requests` … お願いの種類・チップ額（新しい種類も追加できます）
- `RoomNames` … 客室の名前

## ファイル構成

```
roblox/
├── default.project.json      Rojo 用の設定
└── src/
    ├── shared/Config.luau     設定（サーバー・クライアント共通）
    ├── server/
    │   ├── Main.server.luau   起動・増築
    │   ├── WorldBuilder.luau  マップの自動生成
    │   ├── GuestManager.luau  お客様の行動・お世話・評判
    │   └── DataManager.luau   所持金と客室数の保存
    └── client/HUD.client.luau 画面表示（所持金・評判・お知らせ・遊び方）
```
