<?php
/* ============================================================
   ひふみ旅館 採用一元管理システム — API ルーター（PHP）
   共用サーバー対応。Node版(server/)と同じエンドポイントを提供します。

   ルーティング:
   - .htaccess で /api/xxx → /api/index.php?__path=xxx に書き換え（推奨）
   - 書き換えが使えない環境でも /api/index.php?__path=xxx で直接呼べます
   ============================================================ */

error_reporting(E_ALL & ~E_DEPRECATED & ~E_NOTICE);
require __DIR__ . '/db.php';
require __DIR__ . '/connectors.php';
$cfg = require __DIR__ . '/config.php';

/* ---------- CORS / JSON ---------- */
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, x-webhook-secret, x-admin-token');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') { http_response_code(204); exit; }

function respond($code, $obj) { http_response_code($code); header('Content-Type: application/json; charset=utf-8'); echo json_encode($obj, JSON_UNESCAPED_UNICODE); exit; }
function body() { $raw = file_get_contents('php://input'); if ($raw === '' || $raw === false) return []; $d = json_decode($raw, true); return is_array($d) ? $d : ['__parseError'=>true]; }

/* ---------- パス解決 ---------- */
$path = $_GET['__path'] ?? '';
if ($path === '' && isset($_SERVER['PATH_INFO'])) $path = ltrim($_SERVER['PATH_INFO'], '/');
$path = trim($path, '/');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

/* ---------- 管理トークン（設定時のみ） ---------- */
function require_admin($cfg) {
  $t = $cfg['admin_token'] ?? '';
  if ($t === '') return;
  $given = $_SERVER['HTTP_X_ADMIN_TOKEN'] ?? '';
  if (!hash_equals($t, $given)) respond(401, ['ok'=>false,'error'=>'管理トークンが必要です','needToken'=>true]);
}

try {
  $db = new DB($cfg);
  $db->seedIfEmpty();

  /* 求人の解決（外部の求人参照 → 自社の求人） */
  $resolveJob = function($channelId, $norm) use ($db) {
    $jobs = $db->getJobs();
    if (!empty($norm['jobId'])) foreach ($jobs as $j) if ($j['id'] === $norm['jobId']) return $j;
    if (!empty($norm['jobTitle'])) foreach ($jobs as $j) if ($j['title'] === $norm['jobTitle']) return $j;
    foreach ($jobs as $j) if ($j['status'] === 'open' && in_array($channelId, $j['channelIds'], true)) return $j;
    foreach ($jobs as $j) if ($j['status'] === 'open') return $j;
    return null;
  };
  /* 応募の取り込み（全連携共通の入口） */
  $ingest = function($channel, $norm, $source) use ($db, $resolveJob) {
    if (empty($norm['name'])) return ['ok'=>false,'code'=>400,'error'=>'氏名（name）が必要です'];
    $job = $resolveJob($channel['id'], $norm);
    if (!$job) return ['ok'=>false,'code'=>409,'error'=>'取り込み可能な求人がありません（募集中の求人を作成してください）'];
    $app = $db->addApplicant([
      'name'=>mb_substr((string)$norm['name'],0,100),'jobId'=>$job['id'],'channelId'=>$channel['id'],
      'email'=>$norm['email']??'','tel'=>$norm['tel']??'','msg'=>$norm['msg']??'','memo'=>'',
      'status'=>'new','source'=>$source ?: $channel['name'],'appliedAt'=>DB::now(),
    ]);
    return ['ok'=>true,'applicant'=>$app,'job'=>['id'=>$job['id'],'title'=>$job['title']]];
  };

  /* ===== ルーティング ===== */

  // GET /api/health
  if ($path === 'health' && $method === 'GET') respond(200, ['ok'=>true,'service'=>'hifumi-saiyo-php','time'=>DB::now()]);

  // GET /api/state（管理）
  if ($path === 'state' && $method === 'GET') { require_admin($cfg); respond(200, $db->getState()); }

  // PUT /api/state（管理・フル同期）
  if ($path === 'state' && $method === 'PUT') {
    require_admin($cfg);
    $b = body();
    if (!empty($b['__parseError']) || !isset($b['channels']) || !is_array($b['channels'])) respond(400, ['ok'=>false,'error'=>'不正なデータ形式']);
    $db->replaceState($b);
    respond(200, ['ok'=>true]);
  }

  // GET /api/public（応募フォーム用・募集中求人のみ）
  if ($path === 'public' && $method === 'GET') {
    $st = $db->getState();
    $jobs = [];
    foreach ($st['jobs'] as $j) if ($j['status'] === 'open') $jobs[] = ['id'=>$j['id'],'title'=>$j['title'],'emp'=>$j['emp'],'salary'=>$j['salary'],'place'=>$j['place'],'desc'=>$j['desc'],'req'=>$j['req']];
    respond(200, ['ryokan'=>['name'=>$st['ryokan']['name'],'area'=>$st['ryokan']['area']??'','copy'=>$st['ryokan']['copy']??''],'jobs'=>$jobs]);
  }

  // 【#1】POST /api/apply（自社採用サイトからの応募）
  if ($path === 'apply' && $method === 'POST') {
    $b = body();
    if (!empty($b['__parseError'])) respond(400, ['ok'=>false,'error'=>'不正なデータ形式']);
    $chans = $db->getChannels(); $ch = null;
    foreach ($chans as $c) if ($c['connector'] === 'self-site') { $ch = $c; break; }
    if (!$ch) foreach ($chans as $c) if ($c['kind'] === '自社採用サイト') { $ch = $c; break; }
    if (!$ch && count($chans)) $ch = $chans[0];
    if (!$ch) respond(409, ['ok'=>false,'error'=>'応募先の媒体が未登録です']);
    $norm = conn_normalize('self-site', $b, $ch['config']);
    $r = $ingest($ch, $norm, '自社採用サイト');
    respond($r['ok'] ? 201 : ($r['code'] ?? 400), $r);
  }

  // 【#4】POST /api/webhooks/:channelId（各媒体からのWebhook受信）
  if (preg_match('#^webhooks/([^/]+)$#', $path, $m) && $method === 'POST') {
    $ch = $db->getChannel(urldecode($m[1]));
    if (!$ch) respond(404, ['ok'=>false,'error'=>'媒体が見つかりません']);
    if (!conn_auto($ch['connector'])) respond(400, ['ok'=>false,'error'=>"媒体「{$ch['name']}」は自動連携（コネクタ）が設定されていません"]);
    $secret = $ch['config']['secret'] ?? '';
    if ($secret !== '') { $given = $_SERVER['HTTP_X_WEBHOOK_SECRET'] ?? ''; if (!hash_equals($secret, $given)) respond(401, ['ok'=>false,'error'=>'シークレットが一致しません']); }
    $b = body();
    if (!empty($b['__parseError'])) respond(400, ['ok'=>false,'error'=>'不正なデータ形式']);
    $norm = conn_normalize($ch['connector'], $b, $ch['config']);
    $r = $ingest($ch, $norm, $ch['name']);
    respond($r['ok'] ? 201 : ($r['code'] ?? 400), $r);
  }

  // 【#4 動作確認】POST /api/channels/:id/simulate（テスト受信）
  if (preg_match('#^channels/([^/]+)/simulate$#', $path, $m) && $method === 'POST') {
    require_admin($cfg);
    $ch = $db->getChannel(urldecode($m[1]));
    if (!$ch) respond(404, ['ok'=>false,'error'=>'媒体が見つかりません']);
    if (!conn_auto($ch['connector'])) respond(400, ['ok'=>false,'error'=>"媒体「{$ch['name']}」は自動連携が未設定です"]);
    $names = ['山田 太郎','中川 綾','木村 直樹','林 芽依','清水 拓海','森本 千夏','岡田 悠','藤田 美月'];
    $pick = $names[array_rand($names)];
    $payload = conn_sample($ch['connector'], $ch['config']);
    if ($ch['connector'] === 'indeed') $payload['applicant']['fullName'] = $pick;
    elseif (!empty($ch['config']['fieldMap']['name'])) $payload[$ch['config']['fieldMap']['name']] = $pick;
    else $payload['name'] = $pick;
    $norm = conn_normalize($ch['connector'], $payload, $ch['config']);
    $r = $ingest($ch, $norm, "{$ch['name']}（テスト受信）");
    respond($r['ok'] ? 201 : ($r['code'] ?? 400), $r);
  }

  respond(404, ['ok'=>false,'error'=>'エンドポイントが存在しません: '.$path]);
} catch (Throwable $e) {
  respond(500, ['ok'=>false,'error'=>$e->getMessage()]);
}
