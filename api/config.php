<?php
/* ============================================================
   ひふみ旅館 採用一元管理システム — 設定ファイル
   共用サーバーではこのファイルを編集するだけで設定できます。
   ============================================================ */
return [
  // データベースの種類: 'sqlite'（設定不要・推奨） または 'mysql'
  'driver' => getenv('SAIYO_DRIVER') ?: 'sqlite',

  // 【SQLiteの場合】保存先ファイル。data/ フォルダは書き込み可(例:707/777)にしてください。
  //  Web公開領域の外に置ける場合はそちらを推奨します。
  'sqlite_path' => __DIR__ . '/../data/saiyo.sqlite',

  // 【MySQLの場合】共用サーバーの管理画面で発行された値を設定してください。
  'mysql' => [
    'host'    => getenv('SAIYO_DB_HOST') ?: 'localhost',
    'dbname'  => getenv('SAIYO_DB_NAME') ?: 'hifumi_saiyo',
    'user'    => getenv('SAIYO_DB_USER') ?: 'dbuser',
    'pass'    => getenv('SAIYO_DB_PASS') ?: 'dbpass',
    'charset' => 'utf8mb4',
  ],

  // 管理画面(コンソール)の簡易保護トークン。
  //  空文字なら保護なし（誰でも /api/state を読み書き可能）。
  //  公開サーバーでは必ず推測されにくい文字列を設定してください。
  //  設定すると、コンソール初回アクセス時にトークン入力を求められます。
  'admin_token' => getenv('SAIYO_ADMIN_TOKEN') ?: '',
];
