# CLAUDE.md

このリポジトリには 2 つのものが入っています。

- `index.html` … 第八回旅館甲子園の Web サイト（1 ファイルの静的 HTML）
- `roblox/` … Roblox の旅館経営ゲーム「わたしの旅館」（Luau）

## 返答のルール

- ユーザーへの返答・コードのコメント・ゲーム内の文字はすべて**日本語**で書く
- ユーザーは Roblox Studio で動作確認する。こちらの環境では Studio を動かせないので、
  「Studio で未確認」のことははっきり伝え、確認してほしい手順を短く添える

## Roblox ゲーム（roblox/）

### 構成

| ファイル | 役割 | Studio での場所 |
|---|---|---|
| `src/shared/Config.luau` | 数値・文言の設定 | ReplicatedStorage › Shared › Config |
| `src/server/Main.server.luau` | 起動・増築・通知 | ServerScriptService › Main |
| `src/server/WorldBuilder.luau` | マップの自動生成 | ServerScriptService › WorldBuilder |
| `src/server/GuestManager.luau` | お客様の行動・お世話・評判・持ち物 | ServerScriptService › GuestManager |
| `src/server/DataManager.luau` | 所持金・客室数の DataStore 保存 | ServerScriptService › DataManager |
| `src/client/HUD.client.luau` | 画面表示 | StarterPlayerScripts › HUD |

Rojo の対応は `roblox/default.project.json`。ファイルを足したら README の表も更新する。

### 決まりごと

- **マップはすべて WorldBuilder がスクリプトで作る**（ユーザーは Studio でモデリングしない前提）
- 調整できる数値・文言は `Config.luau` に置き、コードに直接書かない
- お金・評判・お世話の判定は**必ずサーバー側**で行う。クライアントは表示だけ
- サーバー → クライアントの通知は `ReplicatedStorage.Remotes.Notify`（RemoteEvent）
- 状態の共有は Attribute を使う（`ReplicatedStorage` の `Reputation`、プレイヤーの `Carrying` / `Rooms`）
- お客様は Humanoid を使わず、anchored パーツのモデルを `PivotTo` で動かす（`walkPath`）
- 文字列フォーマットは `("...%d"):format(x)` の形、インデントはタブ

### 変更したら

```bash
roblox/tools/check.sh   # 全 .luau ファイルの文法チェック
```

文法チェックしかできないので、Roblox API の使い方（プロパティ名・サービス名など）は自分で見直す。
