# ひふみ旅館 採用一元管理システム — 共用サーバー設置手順（PHP版）

一般的な共用（レンタル）サーバー上で、**アップロードするだけで**動作します。
Node.js は不要です（PHP と SQLite だけで動きます）。

## 1. 必要な環境

- **PHP 7.4 以上**（PDO_SQLite 有効。ほぼすべての共用サーバーで標準対応）
- Apache の `.htaccess`（多くの共用サーバーで利用可。無効でも動作します／後述）
- ※ MySQL を使う場合は PHP 7.4 以上 + PDO_MySQL（`api/config.php` で切替）

主要な国内共用サーバー（エックスサーバー、さくらのレンタルサーバ、ロリポップ、
お名前.com など）はいずれも上記条件を満たします。

## 2. アップロードするファイル

FTP などで、公開フォルダ（`public_html` / `www` など）へ次をアップロードします。

```
（公開フォルダ）/
├── saiyo-kanri.html      ← 採用管理コンソール（担当者用）
├── apply.html            ← 応募フォーム（求職者用・自社採用サイト）
├── index.html            ← ※旅館甲子園のページ（不要なら削除可）
├── .htaccess             ← ルーティング設定
├── api/                  ← PHPバックエンド一式
│   ├── index.php
│   ├── config.php            ← 秘密情報は書かない（config.secret.phpを読む）
│   ├── config.secret.php     ← ★DB接続情報など（サーバーにのみ設置・Git管理外）
│   ├── db.php
│   ├── connectors.php
│   └── .htaccess
└── data/                 ← データベース保存先
    └── .htaccess
```

> `server/`（Node.js版）はローカル検証用です。共用サーバーには不要なのでアップロード不要です。

## 3. 設定（`api/config.secret.php`）

DBパスワード等の秘密情報は `api/config.php` には書きません。
**`api/config.secret.php`（サーバーにのみ設置・Git管理外）** に記述します。
既存の `ryokan-php/config.php` と同じ定数名・同じ運用です。

1. `api/config.secret.php.example` をコピーして `api/config.secret.php` を作成
   （※ 本プロジェクトでは、ひふみ旅館の共用サーバーの接続情報を記入した
   `config.secret.php` を別途お渡ししています。それをそのまま `api/` に置けばOKです）。
2. 内容（共用サーバーの MySQL 情報）:
   ```php
   <?php
   define('DB_HOST', 'sddb........cgidb');  // データベースホスト
   define('DB_NAME', 'sddb........');        // データベース名
   define('DB_USER', 'sd_dba_......');       // ユーザー名
   define('DB_PASS', '********');            // パスワード
   define('SAIYO_ADMIN_TOKEN', '長いランダム文字列'); // 管理画面の保護トークン
   ```
3. `config.secret.php` があれば自動的に **MySQL** に接続します（無ければローカル検証用に SQLite）。
4. `SAIYO_ADMIN_TOKEN` を設定すると、コンソール初回アクセス時にトークン入力を求められます
   （応募フォーム `apply.html` には不要）。公開サーバーでは必ず設定してください。

> テーブルは `saiyo_` 接頭辞（`saiyo_channels` 等）で作成されるため、
> 既存の「Ryokan Price」等と同じデータベースを共用しても衝突しません。

## 4. `data/` フォルダの書き込み権限（MySQL利用時は不要）

ひふみ旅館の共用サーバーは **MySQL** を使うため、通常 `data/` の設定は不要です。
（ローカル検証で SQLite を使う場合のみ、`data/` を書き込み可(707/777)にしてください。
初回アクセス時に `data/saiyo.sqlite` が自動生成されます）

## 5. 動作確認

ブラウザで次を開きます（`https://あなたのドメイン/` を読み替えてください）。

| 用途 | URL（ひふみ旅館ドメインの例） |
|---|---|
| 採用管理コンソール | `https://hifumi-kyoto.jp/saiyo-kanri.html` |
| 応募フォーム | `https://hifumi-kyoto.jp/apply.html` |
| 動作確認(API) | `https://hifumi-kyoto.jp/api/health` |

> ※ サブフォルダ（例 `https://hifumi-kyoto.jp/saiyo/`）に設置しても動作します。

- コンソール右上が「**サーバー接続中**」になれば成功です。
- `api/health` が `{"ok":true,...}` を返せばAPIは正常です。
- サブフォルダ（例 `https://ドメイン/saiyo/`）に置いても動作します。

## 6. 求人媒体のAPI連携の設定

コンソールの「**求人媒体 → 各媒体を開く → API連携**」で、媒体ごとの
Webhook 受信URL とシークレットを確認できます。

- **自社採用サイト（#1）** … `apply.html` からの応募が自動で取り込まれます。すぐ使えます。
- **Indeed / 汎用媒体（#4）** … 表示される Webhook URL を各媒体側の連携設定に登録し、
  シークレットを `x-webhook-secret` ヘッダで送るよう設定します。
  実提携前でも「テスト受信（シミュレート）」で取り込み動作を確認できます。

> ※ Indeed の実データ連携には Indeed 側のパートナー審査/ATS連携が前提です。
> タウンワーク・Airワーク・ハローワーク等は一般公開APIがないため、手動入力や
> 応募CSVの運用が中心になります（各媒体の仕様に依存）。

## 7. `.htaccess` が使えない共用サーバーの場合

`.htaccess`（mod_rewrite）が無効な環境でも、フロントエンドは自動的に
`api/index.php?__path=...` 形式にフォールバックするため、そのまま動作します。
特別な設定は不要です。

## 8. セキュリティ上の注意（公開運用時）

- `admin_token` を必ず設定してください（未設定だと誰でも応募者データを閲覧可能）。
- 可能であれば `data/` を公開フォルダの外に置き、`api/config.php` の `sqlite_path` を
  そのパスに変更してください（情報漏えい対策）。
- 常時SSL（https）での運用を推奨します。

## 9. バックアップ

- SQLite … `data/saiyo.sqlite` をダウンロードすれば全データのバックアップになります。
- コンソールの「設定 → JSONで書き出し」でもエクスポートできます。
