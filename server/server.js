'use strict';
/* ============================================================
   ひふみ旅館 採用一元管理システム — バックエンド
   Node.js 標準モジュールのみ（http / fs）+ node:sqlite
   起動: node server.js   （既定ポート 8787）
   ============================================================ */
const http = require('http');
const fs = require('fs');
const path = require('path');
const db = require('./db');
const { getConnector } = require('./connectors');

const ROOT = path.join(__dirname, '..'); // フロント（saiyo-kanri.html / apply.html）を配信
const PORT = parseInt(process.env.PORT, 10) || 8787;

db.seedIfEmpty();

/* ---------- レスポンス補助 ---------- */
const MIME = { '.html':'text/html; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.css':'text/css; charset=utf-8', '.json':'application/json; charset=utf-8', '.svg':'image/svg+xml', '.ico':'image/x-icon', '.png':'image/png', '.jpg':'image/jpeg', '.webp':'image/webp' };
const CORS = { 'Access-Control-Allow-Origin':'*', 'Access-Control-Allow-Methods':'GET,POST,PUT,PATCH,DELETE,OPTIONS', 'Access-Control-Allow-Headers':'Content-Type, x-webhook-secret' };

function json(res, code, obj) { res.writeHead(code, { 'Content-Type':'application/json; charset=utf-8', ...CORS }); res.end(JSON.stringify(obj)); }
function text(res, code, body, type) { res.writeHead(code, { 'Content-Type': type || 'text/plain; charset=utf-8', ...CORS }); res.end(body); }
function readBody(req) {
  return new Promise((resolve) => {
    let d = ''; req.on('data', c => { d += c; if (d.length > 2e6) req.destroy(); });
    req.on('end', () => { if (!d) return resolve({}); try { resolve(JSON.parse(d)); } catch (e) { resolve({ __parseError: true }); } });
  });
}

/* ---------- 求人の解決（外部ペイロードの求人参照 → 自社の求人） ---------- */
function resolveJob(channelId, norm) {
  const jobs = db.getJobs();
  if (norm.jobId) { const j = jobs.find(x => x.id === norm.jobId); if (j) return j; }
  if (norm.jobTitle) { const j = jobs.find(x => x.title === norm.jobTitle); if (j) return j; }
  const onCh = jobs.filter(j => j.status === 'open' && (j.channelIds || []).includes(channelId));
  if (onCh.length) return onCh[0];
  const open = jobs.filter(j => j.status === 'open');
  return open[0] || null;
}

/* ---------- 応募の取り込み（全連携共通の入口） ---------- */
function ingest(channel, norm, source) {
  if (!norm || !norm.name) return { ok: false, code: 400, error: '氏名（name）が必要です' };
  const job = resolveJob(channel.id, norm);
  if (!job) return { ok: false, code: 409, error: '取り込み可能な求人がありません（募集中の求人を作成してください）' };
  const app = db.addApplicant({
    name: String(norm.name).slice(0, 100), jobId: job.id, channelId: channel.id,
    email: norm.email || '', tel: norm.tel || '', msg: norm.msg || '', memo: '',
    status: 'new', source: source || channel.name, appliedAt: Date.now(),
  });
  return { ok: true, applicant: app, job: { id: job.id, title: job.title } };
}

/* ---------- ルーティング ---------- */
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const p = url.pathname;
  const method = req.method;

  if (method === 'OPTIONS') { res.writeHead(204, CORS); return res.end(); }

  try {
    /* ===== API ===== */
    if (p.startsWith('/api/')) {

      // ヘルスチェック（フロントが接続可否を判定）
      if (p === '/api/health' && method === 'GET') return json(res, 200, { ok: true, service: 'hifumi-saiyo', time: Date.now() });

      // 全状態の取得（コンソール用）
      if (p === '/api/state' && method === 'GET') return json(res, 200, db.getState());

      // 全状態の同期（コンソールからのフル保存）
      if (p === '/api/state' && method === 'PUT') {
        const body = await readBody(req);
        if (body.__parseError || !Array.isArray(body.channels)) return json(res, 400, { ok: false, error: '不正なデータ形式' });
        db.replaceState(body);
        return json(res, 200, { ok: true });
      }

      // 公開情報（応募フォーム apply.html 用：募集中の求人のみ）
      if (p === '/api/public' && method === 'GET') {
        const st = db.getState();
        const jobs = st.jobs.filter(j => j.status === 'open').map(j => ({ id: j.id, title: j.title, emp: j.emp, salary: j.salary, place: j.place, desc: j.desc, req: j.req }));
        return json(res, 200, { ryokan: { name: st.ryokan.name, area: st.ryokan.area, copy: st.ryokan.copy }, jobs });
      }

      // 【#1】自社採用サイトからの応募
      if (p === '/api/apply' && method === 'POST') {
        const body = await readBody(req);
        if (body.__parseError) return json(res, 400, { ok: false, error: '不正なデータ形式' });
        // self-site コネクタの媒体を優先的に採用先とする
        const chans = db.getChannels();
        let ch = chans.find(c => c.connector === 'self-site') || chans.find(c => c.kind === '自社採用サイト') || chans[0];
        if (!ch) return json(res, 409, { ok: false, error: '応募先の媒体が未登録です' });
        const norm = getConnector('self-site').normalize(body, ch.config);
        const r = ingest(ch, norm, '自社採用サイト');
        return json(res, r.ok ? 201 : (r.code || 400), r);
      }

      // 【#4】各媒体からの Webhook 受信： /api/webhooks/:channelId
      let m = p.match(/^\/api\/webhooks\/([^/]+)$/);
      if (m && method === 'POST') {
        const ch = db.getChannel(decodeURIComponent(m[1]));
        if (!ch) return json(res, 404, { ok: false, error: '媒体が見つかりません' });
        const conn = getConnector(ch.connector);
        if (!conn.auto) return json(res, 400, { ok: false, error: `媒体「${ch.name}」は自動連携（コネクタ）が設定されていません` });
        // シークレット検証（設定されている場合）
        const secret = (ch.config && ch.config.secret) || '';
        if (secret) {
          const given = req.headers['x-webhook-secret'] || '';
          if (given !== secret) return json(res, 401, { ok: false, error: 'シークレットが一致しません' });
        }
        const body = await readBody(req);
        if (body.__parseError) return json(res, 400, { ok: false, error: '不正なデータ形式' });
        const norm = conn.normalize(body, ch.config);
        const r = ingest(ch, norm, ch.name);
        return json(res, r.ok ? 201 : (r.code || 400), r);
      }

      // 【#4 動作確認】連携シミュレーション： /api/channels/:id/simulate
      m = p.match(/^\/api\/channels\/([^/]+)\/simulate$/);
      if (m && method === 'POST') {
        const ch = db.getChannel(decodeURIComponent(m[1]));
        if (!ch) return json(res, 404, { ok: false, error: '媒体が見つかりません' });
        const conn = getConnector(ch.connector);
        if (!conn.auto) return json(res, 400, { ok: false, error: `媒体「${ch.name}」は自動連携が未設定です（連携方法を設定してください）` });
        // コネクタのサンプル受信 or ランダム応募者を生成
        const names = ['山田 太郎','中川 綾','木村 直樹','林 芽依','清水 拓海','森本 千夏','岡田 悠','藤田 美月'];
        const pick = names[Math.floor(Math.random() * names.length)];
        let payload = conn.sample ? conn.sample(ch.config) : {};
        // sample の氏名をランダム化して重複を避ける
        if (conn === getConnector('indeed')) payload.applicant.fullName = pick;
        else if (ch.config && ch.config.fieldMap && ch.config.fieldMap.name) payload[ch.config.fieldMap.name] = pick;
        else payload.name = pick;
        const norm = conn.normalize(payload, ch.config);
        const r = ingest(ch, norm, `${ch.name}（テスト受信）`);
        return json(res, r.ok ? 201 : (r.code || 400), r);
      }

      return json(res, 404, { ok: false, error: 'エンドポイントが存在しません' });
    }

    /* ===== 静的ファイル配信 ===== */
    let rel = decodeURIComponent(p);
    if (rel === '/' ) rel = '/saiyo-kanri.html';
    // ディレクトリトラバーサル防止
    const filePath = path.normalize(path.join(ROOT, rel));
    if (!filePath.startsWith(ROOT)) return text(res, 403, 'Forbidden');
    if (method !== 'GET') return text(res, 405, 'Method Not Allowed');

    fs.readFile(filePath, (err, data) => {
      if (err) return text(res, 404, 'Not Found');
      const ext = path.extname(filePath).toLowerCase();
      text(res, 200, data, MIME[ext] || 'application/octet-stream');
    });
  } catch (e) {
    json(res, 500, { ok: false, error: String(e && e.message || e) });
  }
});

server.listen(PORT, () => {
  console.log('============================================================');
  console.log(' ひふみ旅館 採用一元管理システム — バックエンド起動');
  console.log('============================================================');
  console.log(` 管理コンソール : http://localhost:${PORT}/saiyo-kanri.html`);
  console.log(` 応募フォーム   : http://localhost:${PORT}/apply.html`);
  console.log(` API ヘルス     : http://localhost:${PORT}/api/health`);
  console.log('------------------------------------------------------------');
});
