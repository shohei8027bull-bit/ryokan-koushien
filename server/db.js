'use strict';
/* ============================================================
   ひふみ旅館 採用一元管理システム — 永続化レイヤ
   Node.js 標準の node:sqlite を使用（追加インストール不要）
   ============================================================ */
const { DatabaseSync } = require('node:sqlite');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'saiyo.db');
const db = new DatabaseSync(DB_PATH);

db.exec(`
  CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
  CREATE TABLE IF NOT EXISTS channels (
    id TEXT PRIMARY KEY, name TEXT, kind TEXT, status TEXT, cost INTEGER,
    color TEXT, note TEXT, connector TEXT, config TEXT, created_at INTEGER
  );
  CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY, title TEXT, emp TEXT, salary TEXT, place TEXT,
    descr TEXT, req TEXT, status TEXT, channel_ids TEXT, created_at INTEGER
  );
  CREATE TABLE IF NOT EXISTS applicants (
    id TEXT PRIMARY KEY, name TEXT, job_id TEXT, channel_id TEXT, email TEXT,
    tel TEXT, msg TEXT, memo TEXT, status TEXT, source TEXT, applied_at INTEGER
  );
`);

/* ---------- id 生成 ---------- */
let _seq = 1;
function uid(p) { return p + '_' + (_seq++).toString(36) + Date.now().toString(36).slice(-4); }

/* ---------- 行 <-> オブジェクト 変換 ---------- */
function chFromRow(r) {
  return { id: r.id, name: r.name, kind: r.kind, status: r.status, cost: r.cost || 0,
    color: r.color, note: r.note || '', connector: r.connector || 'manual',
    config: r.config ? JSON.parse(r.config) : {}, createdAt: r.created_at };
}
function jobFromRow(r) {
  return { id: r.id, title: r.title, emp: r.emp, salary: r.salary, place: r.place,
    desc: r.descr || '', req: r.req || '', status: r.status,
    channelIds: r.channel_ids ? JSON.parse(r.channel_ids) : [], createdAt: r.created_at };
}
function appFromRow(r) {
  return { id: r.id, name: r.name, jobId: r.job_id, channelId: r.channel_id, email: r.email || '',
    tel: r.tel || '', msg: r.msg || '', memo: r.memo || '', status: r.status,
    source: r.source || '', appliedAt: r.applied_at };
}

/* ---------- 参照 ---------- */
function getMeta(key, def) { const r = db.prepare('SELECT value FROM meta WHERE key=?').get(key); return r ? JSON.parse(r.value) : def; }
function setMeta(key, val) { db.prepare('INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key, JSON.stringify(val)); }

function getChannels() { return db.prepare('SELECT * FROM channels ORDER BY created_at ASC').all().map(chFromRow); }
function getJobs() { return db.prepare('SELECT * FROM jobs ORDER BY created_at DESC').all().map(jobFromRow); }
function getApplicants() { return db.prepare('SELECT * FROM applicants ORDER BY applied_at DESC').all().map(appFromRow); }
function getChannel(id) { const r = db.prepare('SELECT * FROM channels WHERE id=?').get(id); return r ? chFromRow(r) : null; }

function getState() {
  return { ryokan: getMeta('ryokan', { name: 'ひふみ旅館', area: '', copy: '' }),
    channels: getChannels(), jobs: getJobs(), apps: getApplicants() };
}

/* ---------- 書き込み ---------- */
const insCh = db.prepare('INSERT INTO channels(id,name,kind,status,cost,color,note,connector,config,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)');
const insJob = db.prepare('INSERT INTO jobs(id,title,emp,salary,place,descr,req,status,channel_ids,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)');
const insApp = db.prepare('INSERT INTO applicants(id,name,job_id,channel_id,email,tel,msg,memo,status,source,applied_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)');

function insertChannel(c) { insCh.run(c.id, c.name, c.kind, c.status, c.cost||0, c.color, c.note||'', c.connector||'manual', JSON.stringify(c.config||{}), c.createdAt||Date.now()); }
function insertJob(j) { insJob.run(j.id, j.title, j.emp, j.salary, j.place, j.desc||'', j.req||'', j.status, JSON.stringify(j.channelIds||[]), j.createdAt||Date.now()); }
function insertApplicant(a) { insApp.run(a.id, a.name, a.jobId, a.channelId, a.email||'', a.tel||'', a.msg||'', a.memo||'', a.status||'new', a.source||'', a.appliedAt||Date.now()); }

function addApplicant(a) { if (!a.id) a.id = uid('a'); if (!a.appliedAt) a.appliedAt = Date.now(); insertApplicant(a); return a; }

/* コンソールからの全状態同期（フルリプレース） */
function replaceState(state) {
  const tx = db.prepare('SELECT 1'); // ダミー
  db.exec('BEGIN');
  try {
    db.exec('DELETE FROM channels; DELETE FROM jobs; DELETE FROM applicants;');
    (state.channels || []).forEach(insertChannel);
    (state.jobs || []).forEach(insertJob);
    (state.apps || []).forEach(insertApplicant);
    if (state.ryokan) setMeta('ryokan', state.ryokan);
    db.exec('COMMIT');
  } catch (e) { db.exec('ROLLBACK'); throw e; }
}

/* ---------- サンプルデータ投入（京都駅前・ひふみ旅館） ---------- */
function seedIfEmpty() {
  const n = db.prepare('SELECT COUNT(*) c FROM channels').get().c;
  if (n > 0) return false;
  setMeta('ryokan', { name: 'ひふみ旅館', area: '京都府・京都駅前',
    copy: '京都駅から徒歩5分。国内外のお客様を和のおもてなしでお迎えする町家旅館です。スタッフの笑顔がいちばんのおもてなしです。' });

  const ch = (name, kind, status, cost, color, connector, config) => {
    const id = uid('c'); insertChannel({ id, name, kind, status, cost, color, note:'', connector: connector||'manual', config: config||{}, createdAt: Date.now()-86400000*30 }); return id;
  };
  const cIndeed = ch('Indeed', '有料求人媒体', 'active', 50000, '#2557A7', 'indeed', { secret: 'demo-indeed-secret' });
  const cTown   = ch('タウンワーク', '有料求人媒体', 'active', 80000, '#FF6A6A', 'manual', {});
  const cAir    = ch('Airワーク', '無料求人媒体', 'active', 0, '#F2994A', 'manual', {});
  const cHello  = ch('ハローワーク', 'ハローワーク', 'active', 0, '#2F8F5B', 'manual', {});
  const cOwn    = ch('自社採用サイト', '自社採用サイト', 'active', 0, '#0D1F3C', 'self-site', {});
  const cOmo    = ch('おもてなしHR', '有料求人媒体', 'paused', 60000, '#00A4BD', 'generic-webhook', { secret: 'demo-omo-secret', fieldMap: { name:'candidate_name', email:'mail', tel:'phone', msg:'motivation', jobTitle:'position' } });

  const job = (title, emp, salary, place, desc, req, channelIds) => {
    const id = uid('j'); insertJob({ id, title, emp, salary, place, desc, req, status:'open', channelIds, createdAt: Date.now()-86400000*20 }); return id;
  };
  const jFront = job('フロント・接客スタッフ', '正社員', '月給 23〜28万円', '京都市下京区（京都駅より徒歩5分）', 'チェックイン・チェックアウト対応、館内案内、予約管理を担当いただきます。英語での接客歓迎、未経験からでも先輩がしっかりサポートします。', '未経験可／おもてなしに興味のある方', [cIndeed, cTown, cOwn, cHello]);
  const jClean = job('客室清掃スタッフ', 'パート・アルバイト', '時給 1,150円〜', '京都市下京区（京都駅より徒歩5分）', '客室の清掃・ベッドメイキング。短時間勤務・扶養内OK、シフト相談可。', '未経験歓迎／シニア活躍中', [cAir, cTown, cHello]);
  const jCook  = job('調理補助', 'パート・アルバイト', '時給 1,200円〜', '京都市下京区（京都駅より徒歩5分）', '朝夕の料理の盛り付け・下ごしらえ・洗い場など。板前のもとで学べます。', '未経験可', [cIndeed, cAir]);
  const jRsv   = job('予約・電話対応スタッフ', '契約社員', '月給 20〜24万円', '京都市下京区（一部在宅可）', '電話・メール・OTAサイトの予約管理。PC基本操作ができる方歓迎。', 'PC基本操作／接客経験優遇', [cOwn, cIndeed]);

  const app = (name, jobId, chId, status, days, email, tel, msg, source) => addApplicant({ name, jobId, channelId: chId, status, email, tel, msg, source: source||'', appliedAt: Date.now()-86400000*days });
  app('田中 美咲', jFront, cIndeed, 'interview', 5, 'tanaka@example.com', '090-1234-5678', '接客業の経験を活かして、地域に根ざした宿で働きたいです。', 'Indeed Apply');
  app('佐藤 健一', jCook, cAir, 'new', 1, 'sato@example.com', '080-2222-3333', '調理の世界に挑戦したいです。');
  app('鈴木 里奈', jFront, cTown, 'screening', 3, 'suzuki@example.com', '070-4444-5555', '未経験ですが、おもてなしを学びたいです。');
  app('高橋 由美', jClean, cHello, 'offer', 9, 'takahashi@example.com', '090-6666-7777', '地元で長く働ける職場を探しています。');
  app('伊藤 翔',   jFront, cTown, 'new', 0, 'ito@example.com', '080-8888-9999', 'ホテルでのフロント経験があります。');
  app('渡辺 彩',   jRsv, cOwn, 'screening', 4, 'watanabe@example.com', '070-1111-2222', '予約管理の実務経験があります。在宅勤務にも興味があります。', '自社採用サイト');
  app('山本 大輔', jClean, cTown, 'rejected', 12, 'yamamoto@example.com', '090-3333-1111', '');
  app('中村 花子', jCook, cIndeed, 'interview', 6, 'nakamura@example.com', '080-5555-6666', '朝の時間帯で働きたいです。', 'Indeed Apply');
  app('小林 誠',   jFront, cIndeed, 'new', 2, 'kobayashi@example.com', '070-7777-8888', '接客が好きです。京都で働きたく、駅近の勤務地に惹かれました。', 'Indeed Apply');
  return true;
}

module.exports = {
  uid, getState, getChannels, getJobs, getApplicants, getChannel,
  getMeta, setMeta, addApplicant, replaceState, seedIfEmpty,
};
