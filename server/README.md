# ひふみ旅館 採用一元管理システム — バックエンド

複数の求人媒体（Indeed・タウンワーク・自社採用サイト等）からの応募を
1つの選考パイプラインに集約するための API サーバーです。

- **依存パッケージなし**（Node.js 標準モジュール + `node:sqlite` のみ）
- `npm install` 不要。`node server.js` だけで起動します
- データは `server/saiyo.db`（SQLite）に保存されます

## 動作要件

- **Node.js 22.5 以上**（`node:sqlite` を使用するため）

## 起動

```bash
cd server
node server.js
# もしくは
npm start
```

起動後、次のURLが利用できます。

| 用途 | URL |
|---|---|
| 採用管理コンソール | http://localhost:8787/saiyo-kanri.html |
| 応募フォーム（自社採用サイト） | http://localhost:8787/apply.html |
| APIヘルスチェック | http://localhost:8787/api/health |

> ポートを変える場合は `PORT=3000 node server.js`、
> DBの保存先を変える場合は `DB_PATH=/path/to/saiyo.db node server.js`。

コンソールをサーバー経由（`http://localhost:8787/saiyo-kanri.html`）で開くと
自動的にサーバー接続モードになり、右上に「サーバー接続中」と表示されます。
サーバーを起動せずファイルを直接開いた場合は「ローカル保存」モード（localStorage）で動作します。

## 応募の流れ（一元管理）

```
 自社採用サイト(apply.html) ─┐
 Indeed Apply (Webhook) ─────┤
 汎用媒体 (Webhook) ─────────┼──▶  バックエンド  ──▶  選考パイプライン（新規→書類選考→面接→内定）
 手動入力 / CSV ─────────────┘        (SQLite)            コンソールに一元表示
```

## API エンドポイント

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/api/health` | 稼働確認 |
| GET | `/api/state` | 全データ取得（コンソール用） |
| PUT | `/api/state` | 全データ同期（コンソールからの保存） |
| GET | `/api/public` | 公開情報（応募フォーム用・募集中求人のみ） |
| POST | `/api/apply` | **【#1】自社採用サイトからの応募受付** |
| POST | `/api/webhooks/:channelId` | **【#4】各媒体からの Webhook 受信** |
| POST | `/api/channels/:channelId/simulate` | 連携の動作確認（テスト応募を生成） |

### 【#1】自社採用サイト応募

`apply.html` のフォーム送信がこのエンドポイントに届きます。

```bash
curl -X POST http://localhost:8787/api/apply \
  -H 'Content-Type: application/json' \
  -d '{"name":"山田 太郎","jobId":"<求人ID>","email":"taro@example.com","tel":"090-0000-0000","msg":"志望動機"}'
```

`jobId` は `/api/public` の求人一覧から取得します（フォームは自動で付与）。

### 【#4】媒体 Webhook 受信

媒体ごとに発行される受信URL（`/api/webhooks/:channelId`）に、
その媒体からの応募をPOSTすると、コネクタが共通形式へ変換して取り込みます。
コンソールの「求人媒体 → 各媒体 → API連携」でURLとシークレットを確認できます。

```bash
# Indeed Apply（indeed コネクタ）の例
curl -X POST http://localhost:8787/api/webhooks/<channelId> \
  -H 'Content-Type: application/json' \
  -H 'x-webhook-secret: <媒体のシークレット>' \
  -d '{"applicant":{"fullName":"応募 太郎","email":"a@example.com","phoneNumber":"090-0000-0000"},
       "job":{"jobTitle":"フロント・接客スタッフ"},"coverletter":"応募します"}'
```

シークレットが設定されている媒体では、`x-webhook-secret` ヘッダの一致を検証します。
（不一致は 401 で拒否）

## コネクタ（`connectors.js`）

媒体ごとの受信ペイロードを共通形式 `{name, email, tel, msg, jobId, jobTitle}` に正規化します。

| コネクタ | 用途 | 備考 |
|---|---|---|
| `manual` | 手動入力 | 自動連携なし。手動追加・CSV運用 |
| `self-site` | 自社採用サイト | `apply.html` フォーム直結（#1） |
| `indeed` | Indeed Apply | 代表的な Apply ペイロードをマッピング（#4） |
| `generic-webhook` | 汎用媒体 | `config.fieldMap` で相手キー→共通キーを対応づけ（#4） |

新しい媒体を追加する場合は `CONNECTORS` に `normalize(payload, config)` を実装するだけで対応できます。

## 各媒体の連携についての注意（現実的な話）

- **自社採用サイト（#1）** … 本リポジトリの `apply.html` で完結。すぐ使えます。
- **Indeed** … 実データ連携には Indeed のパートナー審査/ATS連携が必要です。審査通過後、
  Apply/Disposition の Webhook を `/api/webhooks/:channelId` に向けてください。
- **タウンワーク / Airワーク / ハローワーク** … 一般公開APIは基本提供されていないため、
  多くは「手動入力」または応募CSVの取り込み運用になります（媒体側の仕様に依存）。
- 上記のため、実提携がまだの媒体でも動作を確認できるよう
  **シミュレート受信**（コンソールの「テスト受信」ボタン／`/simulate`）を用意しています。

## 本番運用に向けて（未対応事項）

このバックエンドはデモ・社内利用を想定した最小構成です。実運用では次を追加してください。

- 管理コンソールの認証（現状は誰でも `/api/state` を読み書き可能）
- Webhook の署名検証強化（HMAC 等）／IP制限
- `PUT /api/state` は全置換のため、多人数同時編集には不向き（項目単位のAPIに分割推奨）
- バックアップ、HTTPS、ログ
