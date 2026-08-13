<?php
/* ============================================================
   ひふみ旅館 採用一元管理システム — 永続化レイヤ（PDO）
   SQLite / MySQL の両対応。共用サーバー(MySQL)でそのまま動作します。
   テーブルは saiyo_ 接頭辞（既存アプリとの共存のため）。
   ============================================================ */

class DB {
  private $pdo;
  private $driver;
  // テーブル名（既存DBと共存できるよう接頭辞つき）
  private $tMeta = 'saiyo_meta';
  private $tCh   = 'saiyo_channels';
  private $tJob  = 'saiyo_jobs';
  private $tApp  = 'saiyo_applicants';

  function __construct($cfg) {
    $this->driver = $cfg['driver'];
    if ($this->driver === 'mysql') {
      $m = $cfg['mysql'];
      $dsn = "mysql:host={$m['host']};dbname={$m['dbname']};charset={$m['charset']}";
      $this->pdo = new PDO($dsn, $m['user'], $m['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
      ]);
    } else {
      $path = $cfg['sqlite_path'];
      if (!is_dir(dirname($path))) @mkdir(dirname($path), 0777, true);
      $this->pdo = new PDO('sqlite:' . $path, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
      ]);
    }
    $this->migrate();
  }

  private function migrate() {
    $idType = $this->driver === 'mysql' ? 'VARCHAR(40)' : 'TEXT';
    $intType = $this->driver === 'mysql' ? 'BIGINT' : 'INTEGER';
    $eng = $this->driver === 'mysql' ? ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' : '';
    $this->pdo->exec("CREATE TABLE IF NOT EXISTS {$this->tMeta} (k $idType PRIMARY KEY, v TEXT)$eng");
    $this->pdo->exec("CREATE TABLE IF NOT EXISTS {$this->tCh} (
      id $idType PRIMARY KEY, name TEXT, kind TEXT, status TEXT, cost INT,
      color TEXT, note TEXT, connector TEXT, config TEXT, created_at $intType)$eng");
    $this->pdo->exec("CREATE TABLE IF NOT EXISTS {$this->tJob} (
      id $idType PRIMARY KEY, title TEXT, emp TEXT, salary TEXT, place TEXT,
      descr TEXT, req TEXT, status TEXT, channel_ids TEXT, created_at $intType)$eng");
    $this->pdo->exec("CREATE TABLE IF NOT EXISTS {$this->tApp} (
      id $idType PRIMARY KEY, name TEXT, job_id $idType, channel_id $idType, email TEXT,
      tel TEXT, msg TEXT, memo TEXT, status TEXT, source TEXT, applied_at $intType)$eng");
  }

  /* ---------- id 生成 ---------- */
  static function uid($p) { return $p . '_' . substr(bin2hex(random_bytes(6)), 0, 9); }
  static function now() { return (int) round(microtime(true) * 1000); }

  /* ---------- 行 <-> 配列 変換（フロントのフィールド名に合わせる） ---------- */
  private function chFromRow($r) {
    return ['id'=>$r['id'],'name'=>$r['name'],'kind'=>$r['kind'],'status'=>$r['status'],
      'cost'=>(int)$r['cost'],'color'=>$r['color'],'note'=>$r['note']??'',
      'connector'=>$r['connector']?:'manual','config'=>$r['config']?json_decode($r['config'],true):new stdClass(),
      'createdAt'=>(int)$r['created_at']];
  }
  private function jobFromRow($r) {
    return ['id'=>$r['id'],'title'=>$r['title'],'emp'=>$r['emp'],'salary'=>$r['salary'],'place'=>$r['place'],
      'desc'=>$r['descr']??'','req'=>$r['req']??'','status'=>$r['status'],
      'channelIds'=>$r['channel_ids']?json_decode($r['channel_ids'],true):[],'createdAt'=>(int)$r['created_at']];
  }
  private function appFromRow($r) {
    return ['id'=>$r['id'],'name'=>$r['name'],'jobId'=>$r['job_id'],'channelId'=>$r['channel_id'],
      'email'=>$r['email']??'','tel'=>$r['tel']??'','msg'=>$r['msg']??'','memo'=>$r['memo']??'',
      'status'=>$r['status'],'source'=>$r['source']??'','appliedAt'=>(int)$r['applied_at']];
  }

  /* ---------- 参照 ---------- */
  function getMeta($k, $def) { $s=$this->pdo->prepare("SELECT v FROM {$this->tMeta} WHERE k=?"); $s->execute([$k]); $r=$s->fetch(); return $r?json_decode($r['v'],true):$def; }
  function setMeta($k, $val) {
    $json = json_encode($val, JSON_UNESCAPED_UNICODE);
    if ($this->driver === 'mysql') $sql="INSERT INTO {$this->tMeta}(k,v) VALUES(?,?) ON DUPLICATE KEY UPDATE v=VALUES(v)";
    else $sql="INSERT INTO {$this->tMeta}(k,v) VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v";
    $this->pdo->prepare($sql)->execute([$k, $json]);
  }
  function getChannels() { return array_map([$this,'chFromRow'], $this->pdo->query("SELECT * FROM {$this->tCh} ORDER BY created_at ASC")->fetchAll()); }
  function getJobs() { return array_map([$this,'jobFromRow'], $this->pdo->query("SELECT * FROM {$this->tJob} ORDER BY created_at DESC")->fetchAll()); }
  function getApplicants() { return array_map([$this,'appFromRow'], $this->pdo->query("SELECT * FROM {$this->tApp} ORDER BY applied_at DESC")->fetchAll()); }
  function getChannel($id) { $s=$this->pdo->prepare("SELECT * FROM {$this->tCh} WHERE id=?"); $s->execute([$id]); $r=$s->fetch(); return $r?$this->chFromRow($r):null; }

  function getState() {
    return ['ryokan'=>$this->getMeta('ryokan', ['name'=>'ひふみ旅館','area'=>'','copy'=>'']),
      'channels'=>$this->getChannels(),'jobs'=>$this->getJobs(),'apps'=>$this->getApplicants()];
  }

  /* ---------- 書き込み ---------- */
  private function insertChannel($c) {
    $this->pdo->prepare("INSERT INTO {$this->tCh}(id,name,kind,status,cost,color,note,connector,config,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)")
      ->execute([$c['id'],$c['name'],$c['kind'],$c['status'],(int)($c['cost']??0),$c['color'],$c['note']??'',$c['connector']??'manual',json_encode($c['config']??[],JSON_UNESCAPED_UNICODE),$c['createdAt']??self::now()]);
  }
  private function insertJob($j) {
    $this->pdo->prepare("INSERT INTO {$this->tJob}(id,title,emp,salary,place,descr,req,status,channel_ids,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)")
      ->execute([$j['id'],$j['title'],$j['emp'],$j['salary'],$j['place'],$j['desc']??'',$j['req']??'',$j['status'],json_encode($j['channelIds']??[],JSON_UNESCAPED_UNICODE),$j['createdAt']??self::now()]);
  }
  private function insertApplicant($a) {
    $this->pdo->prepare("INSERT INTO {$this->tApp}(id,name,job_id,channel_id,email,tel,msg,memo,status,source,applied_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)")
      ->execute([$a['id'],$a['name'],$a['jobId'],$a['channelId'],$a['email']??'',$a['tel']??'',$a['msg']??'',$a['memo']??'',$a['status']??'new',$a['source']??'',$a['appliedAt']??self::now()]);
  }
  function addApplicant($a) {
    if (empty($a['id'])) $a['id'] = self::uid('a');
    if (empty($a['appliedAt'])) $a['appliedAt'] = self::now();
    $this->insertApplicant($a);
    return $a;
  }

  /* コンソールからの全状態同期（フルリプレース） */
  function replaceState($state) {
    $this->pdo->beginTransaction();
    try {
      $this->pdo->exec("DELETE FROM {$this->tCh}"); $this->pdo->exec("DELETE FROM {$this->tJob}"); $this->pdo->exec("DELETE FROM {$this->tApp}");
      foreach (($state['channels']??[]) as $c) $this->insertChannel($c);
      foreach (($state['jobs']??[]) as $j) $this->insertJob($j);
      foreach (($state['apps']??[]) as $a) $this->insertApplicant($a);
      if (!empty($state['ryokan'])) $this->setMeta('ryokan', $state['ryokan']);
      $this->pdo->commit();
    } catch (Exception $e) { $this->pdo->rollBack(); throw $e; }
  }

  /* ---------- サンプルデータ（京都駅前・ひふみ旅館） ---------- */
  function seedIfEmpty() {
    $n = (int) $this->pdo->query("SELECT COUNT(*) c FROM {$this->tCh}")->fetch()['c'];
    if ($n > 0) return false;
    $this->setMeta('ryokan', ['name'=>'ひふみ旅館','area'=>'京都府・京都駅前',
      'copy'=>'京都駅から徒歩5分。国内外のお客様を和のおもてなしでお迎えする町家旅館です。スタッフの笑顔がいちばんのおもてなしです。']);

    $ch = function($name,$kind,$status,$cost,$color,$connector='manual',$config=[]) {
      $id = self::uid('c'); $this->insertChannel(compact('id','name','kind','status','cost','color','connector','config')+['note'=>'','createdAt'=>self::now()-86400000*30]); return $id;
    };
    $cIndeed = $ch('Indeed','有料求人媒体','active',50000,'#2557A7','indeed',['secret'=>'demo-indeed-secret']);
    $cTown   = $ch('タウンワーク','有料求人媒体','active',80000,'#FF6A6A');
    $cAir    = $ch('Airワーク','無料求人媒体','active',0,'#F2994A');
    $cHello  = $ch('ハローワーク','ハローワーク','active',0,'#2F8F5B');
    $cOwn    = $ch('自社採用サイト','自社採用サイト','active',0,'#0D1F3C','self-site');
    $cOmo    = $ch('おもてなしHR','有料求人媒体','paused',60000,'#00A4BD','generic-webhook',['secret'=>'demo-omo-secret','fieldMap'=>['name'=>'candidate_name','email'=>'mail','tel'=>'phone','msg'=>'motivation','jobTitle'=>'position']]);

    $job = function($title,$emp,$salary,$place,$desc,$req,$channelIds) {
      $id = self::uid('j'); $this->insertJob(compact('id','title','emp','salary','place','desc','req','channelIds')+['status'=>'open','createdAt'=>self::now()-86400000*20]); return $id;
    };
    $jFront = $job('フロント・接客スタッフ','正社員','月給 23〜28万円','京都市下京区（京都駅より徒歩5分）','チェックイン・チェックアウト対応、館内案内、予約管理を担当いただきます。英語での接客歓迎、未経験からでも先輩がしっかりサポートします。','未経験可／おもてなしに興味のある方',[$cIndeed,$cTown,$cOwn,$cHello]);
    $jClean = $job('客室清掃スタッフ','パート・アルバイト','時給 1,150円〜','京都市下京区（京都駅より徒歩5分）','客室の清掃・ベッドメイキング。短時間勤務・扶養内OK、シフト相談可。','未経験歓迎／シニア活躍中',[$cAir,$cTown,$cHello]);
    $jCook  = $job('調理補助','パート・アルバイト','時給 1,200円〜','京都市下京区（京都駅より徒歩5分）','朝夕の料理の盛り付け・下ごしらえ・洗い場など。板前のもとで学べます。','未経験可',[$cIndeed,$cAir]);
    $jRsv   = $job('予約・電話対応スタッフ','契約社員','月給 20〜24万円','京都市下京区（一部在宅可）','電話・メール・OTAサイトの予約管理。PC基本操作ができる方歓迎。','PC基本操作／接客経験優遇',[$cOwn,$cIndeed]);

    $app = function($name,$jobId,$chId,$status,$days,$email,$tel,$msg,$source='') {
      $this->addApplicant(['name'=>$name,'jobId'=>$jobId,'channelId'=>$chId,'status'=>$status,'email'=>$email,'tel'=>$tel,'msg'=>$msg,'source'=>$source,'appliedAt'=>self::now()-86400000*$days]);
    };
    $app('田中 美咲',$jFront,$cIndeed,'interview',5,'tanaka@example.com','090-1234-5678','接客業の経験を活かして、地域に根ざした宿で働きたいです。','Indeed Apply');
    $app('佐藤 健一',$jCook,$cAir,'new',1,'sato@example.com','080-2222-3333','調理の世界に挑戦したいです。');
    $app('鈴木 里奈',$jFront,$cTown,'screening',3,'suzuki@example.com','070-4444-5555','未経験ですが、おもてなしを学びたいです。');
    $app('高橋 由美',$jClean,$cHello,'offer',9,'takahashi@example.com','090-6666-7777','地元で長く働ける職場を探しています。');
    $app('伊藤 翔',$jFront,$cTown,'new',0,'ito@example.com','080-8888-9999','ホテルでのフロント経験があります。');
    $app('渡辺 彩',$jRsv,$cOwn,'screening',4,'watanabe@example.com','070-1111-2222','予約管理の実務経験があります。在宅勤務にも興味があります。','自社採用サイト');
    $app('山本 大輔',$jClean,$cTown,'rejected',12,'yamamoto@example.com','090-3333-1111','');
    $app('中村 花子',$jCook,$cIndeed,'interview',6,'nakamura@example.com','080-5555-6666','朝の時間帯で働きたいです。','Indeed Apply');
    $app('小林 誠',$jFront,$cIndeed,'new',2,'kobayashi@example.com','070-7777-8888','接客が好きです。京都で働きたく、駅近の勤務地に惹かれました。','Indeed Apply');
    return true;
  }
}
