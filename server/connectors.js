'use strict';
/* ============================================================
   求人媒体コネクタ（各媒体からの応募データを共通形式へ正規化）
   共通形式: { name, email, tel, msg, jobId, jobTitle }
   ------------------------------------------------------------
   - manual         : 手動入力（自動連携なし）
   - self-site      : 自社採用サイトの応募フォーム（#1）
   - indeed         : Indeed Apply の受信ペイロードを想定（#4）
   - generic-webhook: 任意媒体の Webhook を fieldMap で写像（#4）
   ============================================================ */

const CONNECTORS = {
  'manual': {
    label: '手動入力', auto: false,
    normalize: (p) => ({ name: p.name, email: p.email, tel: p.tel, msg: p.msg, jobId: p.jobId, jobTitle: p.jobTitle }),
  },

  'self-site': {
    label: '自社採用サイト（フォーム直結）', auto: true,
    normalize: (p) => ({
      name: p.name, email: p.email, tel: p.tel,
      msg: p.msg || p.message || '',
      jobId: p.jobId, jobTitle: p.jobTitle,
    }),
  },

  // Indeed Apply の代表的なペイロード形状を想定してマッピング
  // 実運用では Indeed のパートナー審査後、Disposition/Apply Webhook をこのエンドポイントへ向ける
  'indeed': {
    label: 'Indeed Apply', auto: true,
    normalize: (p) => {
      const a = p.applicant || p;
      const name = a.fullName || a.name || [a.firstName, a.lastName].filter(Boolean).join(' ').trim();
      const jobRef = p.job || {};
      return {
        name,
        email: a.email || a.emailAddress || '',
        tel: a.phoneNumber || a.phone || a.tel || '',
        msg: p.coverletter || p.coverLetter || a.coverletter || '',
        jobId: jobRef.jobId || jobRef.id || p.jobId || null,
        jobTitle: jobRef.jobTitle || jobRef.title || p.jobTitle || null,
      };
    },
    // 動作確認用のサンプル受信ペイロード
    sample: () => ({
      applicant: { fullName: '例 応募者', email: 'sample@indeed.test', phoneNumber: '090-0000-0000' },
      job: { jobTitle: 'フロント・接客スタッフ' },
      coverletter: 'Indeed から応募しました。',
    }),
  },

  // 任意の媒体。config.fieldMap で相手側キー→共通キーを対応づける
  'generic-webhook': {
    label: '汎用Webhook', auto: true,
    normalize: (p, cfg) => {
      const fm = (cfg && cfg.fieldMap) || {};
      const g = (key) => (fm[key] && p[fm[key]] != null) ? p[fm[key]] : (p[key] != null ? p[key] : '');
      return {
        name: g('name'), email: g('email'), tel: g('tel'), msg: g('msg'),
        jobId: g('jobId') || null, jobTitle: g('jobTitle') || null,
      };
    },
    sample: (cfg) => {
      const fm = (cfg && cfg.fieldMap) || {};
      const o = {};
      o[fm.name || 'name'] = '例 応募者';
      o[fm.email || 'email'] = 'sample@webhook.test';
      o[fm.tel || 'tel'] = '090-0000-0000';
      o[fm.msg || 'msg'] = 'Webhook 経由の応募テストです。';
      if (fm.jobTitle) o[fm.jobTitle] = 'フロント・接客スタッフ';
      return o;
    },
  },
};

function getConnector(type) { return CONNECTORS[type] || CONNECTORS['manual']; }

module.exports = { CONNECTORS, getConnector };
