<?php
/* ============================================================
   求人媒体コネクタ（各媒体の受信データを共通形式へ正規化）
   共通形式: ['name','email','tel','msg','jobId','jobTitle']
   ============================================================ */

function conn_meta() {
  return [
    'manual'          => ['label'=>'手動入力', 'auto'=>false],
    'self-site'       => ['label'=>'自社採用サイト（フォーム直結）', 'auto'=>true],
    'indeed'          => ['label'=>'Indeed Apply', 'auto'=>true],
    'generic-webhook' => ['label'=>'汎用Webhook', 'auto'=>true],
  ];
}
function conn_auto($type) { $m = conn_meta(); return isset($m[$type]) ? $m[$type]['auto'] : false; }

function conn_normalize($type, $p, $cfg) {
  switch ($type) {
    case 'self-site':
      return ['name'=>$p['name']??null,'email'=>$p['email']??'','tel'=>$p['tel']??'',
        'msg'=>$p['msg']??($p['message']??''),'jobId'=>$p['jobId']??null,'jobTitle'=>$p['jobTitle']??null];

    // Indeed Apply の代表的なペイロード形状を想定
    case 'indeed':
      $a = $p['applicant'] ?? $p;
      $name = $a['fullName'] ?? ($a['name'] ?? trim(($a['firstName']??'').' '.($a['lastName']??'')));
      $job = $p['job'] ?? [];
      return ['name'=>$name,'email'=>$a['email']??($a['emailAddress']??''),
        'tel'=>$a['phoneNumber']??($a['phone']??($a['tel']??'')),
        'msg'=>$p['coverletter']??($p['coverLetter']??''),
        'jobId'=>$job['jobId']??($job['id']??($p['jobId']??null)),
        'jobTitle'=>$job['jobTitle']??($job['title']??($p['jobTitle']??null))];

    // 任意媒体。config.fieldMap で相手側キー→共通キーを対応づけ
    case 'generic-webhook':
      $fm = $cfg['fieldMap'] ?? [];
      $g = function($k) use ($p,$fm) { if (isset($fm[$k]) && isset($p[$fm[$k]])) return $p[$fm[$k]]; return $p[$k]??''; };
      return ['name'=>$g('name'),'email'=>$g('email'),'tel'=>$g('tel'),'msg'=>$g('msg'),
        'jobId'=>$g('jobId')?:null,'jobTitle'=>$g('jobTitle')?:null];

    default:
      return ['name'=>$p['name']??null,'email'=>$p['email']??'','tel'=>$p['tel']??'',
        'msg'=>$p['msg']??'','jobId'=>$p['jobId']??null,'jobTitle'=>$p['jobTitle']??null];
  }
}

function conn_sample($type, $cfg) {
  if ($type === 'indeed') {
    return ['applicant'=>['fullName'=>'例 応募者','email'=>'sample@indeed.test','phoneNumber'=>'090-0000-0000'],
      'job'=>['jobTitle'=>'フロント・接客スタッフ'],'coverletter'=>'Indeedから応募しました。'];
  }
  if ($type === 'generic-webhook') {
    $fm = $cfg['fieldMap'] ?? []; $o = [];
    $o[$fm['name']??'name'] = '例 応募者';
    $o[$fm['email']??'email'] = 'sample@webhook.test';
    $o[$fm['tel']??'tel'] = '090-0000-0000';
    $o[$fm['msg']??'msg'] = 'Webhook経由の応募テストです。';
    if (isset($fm['jobTitle'])) $o[$fm['jobTitle']] = 'フロント・接客スタッフ';
    return $o;
  }
  return [];
}
