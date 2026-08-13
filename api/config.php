<?php
/* ============================================================
   ひふみ旅館 採用一元管理システム — 設定
   ------------------------------------------------------------
   ★ DBパスワード等の秘密情報はこのファイルには書きません。
     サーバー上にのみ置く config.secret.php（Git管理外）から読み込みます。
     （既存の ryokan-php/config.php と同じ運用・同じ定数名 DB_HOST など）
   ============================================================ */

// サーバー限定の秘密設定を読み込む（存在すれば）
if (is_file(__DIR__ . '/config.secret.php')) require __DIR__ . '/config.secret.php';

// DB接続情報が定義されていれば MySQL、なければ SQLite（ローカル検証用）
$hasMysql = defined('DB_HOST') && defined('DB_NAME') && defined('DB_USER');

return [
  // 'mysql'（本番・共用サーバー） または 'sqlite'（ローカル検証）
  'driver' => $hasMysql ? 'mysql' : (getenv('SAIYO_DRIVER') ?: 'sqlite'),

  // SQLite（ローカル検証時のみ使用）
  'sqlite_path' => __DIR__ . '/../data/saiyo.sqlite',

  // MySQL 接続情報（config.secret.php の定数を優先）
  'mysql' => [
    'host'    => defined('DB_HOST') ? DB_HOST : (getenv('SAIYO_DB_HOST') ?: 'localhost'),
    'dbname'  => defined('DB_NAME') ? DB_NAME : (getenv('SAIYO_DB_NAME') ?: ''),
    'user'    => defined('DB_USER') ? DB_USER : (getenv('SAIYO_DB_USER') ?: ''),
    'pass'    => defined('DB_PASS') ? DB_PASS : (getenv('SAIYO_DB_PASS') ?: ''),
    'charset' => 'utf8mb4',
  ],

  // 管理コンソールの保護トークン（config.secret.php で SAIYO_ADMIN_TOKEN を定義）
  //  未設定なら保護なし（公開サーバーでは必ず設定してください）。
  'admin_token' => defined('SAIYO_ADMIN_TOKEN') ? SAIYO_ADMIN_TOKEN : (getenv('SAIYO_ADMIN_TOKEN') ?: ''),
];
