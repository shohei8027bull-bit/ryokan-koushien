# 第八回旅館甲子園 公式サイト

`index.html` 1枚で構成された静的サイトです。

## PCを閉じても公開され続けるようにする（GitHub Pages）

このリポジトリには GitHub Pages への自動公開設定（`.github/workflows/deploy.yml`）が入っています。
一度だけ以下の設定をすれば、あなたのPCの電源に関係なく GitHub がサイトを24時間配信します。

### 初回セットアップ（1回だけ）

1. GitHub でこのリポジトリを開く
2. 上部メニューの **Settings（設定）** を開く
3. 左メニューの **Pages** を選ぶ
4. **Build and deployment** の **Source** を **GitHub Actions** に変更する

これで準備完了です。

### 公開のしくみ

- `main` ブランチに変更が入るたびに、自動でサイトが更新・公開されます。
- 公開URLは `https://<あなたのユーザー名>.github.io/ryokan-koushien/` の形になります。
  （正確なURLは Settings → Pages の上部、または Actions の実行結果に表示されます）
- **Actions** タブの「Deploy to GitHub Pages」→「Run workflow」から手動公開もできます。

### サイトを更新したいとき

`index.html` を編集して `main` ブランチに反映（push / マージ）すれば、
数十秒〜数分で自動的に本番サイトへ反映されます。
