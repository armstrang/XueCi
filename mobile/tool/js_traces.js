/* Traces of the JavaScript learning engine (web/src/learn.js), the reference for the Dart port.

     TZ=UTC node mobile/tool/js_traces.js mobile/test/traces

   Each scenario runs the real store.js + learn.js in a Node vm with a fixed clock and the same seeded chance source
   the Dart tests use (LcgRandom in lib/engine/js.dart), and writes every call and its result to <name>.json:
     {seed, time, band, saved, ops: [{op, a: arguments, o: result}]}
   test/engine_trace_test.dart makes the same calls on the Dart engine and compares the results. Learner behaviour
   (right or wrong, how fast) comes from a hash, never from Math.random, so it is recorded once and replayed exactly. */
'use strict';
process.env.TZ = 'UTC';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..', '..');
const read = (...p) => fs.readFileSync(path.join(ROOT, ...p), 'utf8');
const STORE_JS = read('web', 'src', 'store.js');
const LEARN_JS = read('web', 'src', 'learn.js');
const VOCAB = JSON.parse(read('web', 'data', 'vocab.json'));
const EPOCH = Date.UTC(2026, 0, 1);
const OUT = process.argv[2] || path.join(__dirname, '..', 'test', 'traces');

const PRELUDE = `
const DATA = __VOCAB.filter(d => __band || d.l <= 6).map(d => Object.assign({}, d));
DATA.forEach(d => { d.pm = d.l <= 6 && d.m.split(';')[0].length <= 28 ? 1 : 0 });
const LEVELS = [...new Set(DATA.map(d => d.l))].sort((a, b) => a - b);
const BY = {}; LEVELS.forEach(l => BY[l] = DATA.filter(d => d.l === l));
const TONE = {1:'āēīōūǖĀĒĪŌŪ',2:'áéíóúǘÁÉÍÓÚ',3:'ǎěǐǒǔǚǍĚǏǑǓ',4:'àèìòùǜÀÈÌÒÙ'};
const tone = s => { for (const t in TONE) { for (const c of TONE[t]) if (s.includes(c)) return +t } return 5 };
const plain = s => s.normalize('NFD').replace(/\\p{M}/gu, '').replace(/ü/g, 'v').replace(/['\\s]/g, '').toLowerCase();
DATA.forEach(d => { d.id = d.l + ':' + d.h; d.pk = plain(d.p) });
const IDX = new Map(DATA.map(d => [d.id, d]));
const M = d => d.m, M1 = d => M(d).split(";")[0].trim(), TR = d => d.t;
let stats = ls.get('mm_stats', null); if (!stats || typeof stats !== 'object' || Array.isArray(stats)) stats = {};
for (const k in stats) { const e = stats[k]; if (!Array.isArray(e)) { delete stats[k]; continue } if (e.length < 3) e[2] = Math.max(0, Math.min(20, (e[0] | 0) - (e[1] | 0))) }
const saveStats = () => ls.set('mm_stats', stats);
`;

async function sandbox(saved, { time, seed, band }) {
  const box = new Map(Object.entries(saved));
  const localStorage = {
    get length() {
      return box.size;
    },
    key: i => [...box.keys()][i] ?? null,
    getItem: k => (box.has(k) ? box.get(k) : null),
    setItem: (k, v) => box.set(k, String(v)),
    removeItem: k => box.delete(k),
  };
  const ctx = {
    localStorage,
    setTimeout,
    clearTimeout,
    console,
    __VOCAB: VOCAB,
    __band: band,
    __T: time,
    __seed: seed,
    document: { addEventListener() {}, hidden: false },
    addEventListener() {},
    window: {},
  };
  vm.createContext(ctx);
  /* the clock: Date.now() and new Date() (no arguments) both read the fixed time; Math.random is the shared LCG */
  vm.runInContext(
    `{
      const D = Date;
      Date = class extends D { constructor(...a) { if (a.length) super(...a); else super(globalThis.__T); } static now() { return globalThis.__T; } };
    }
    Math.random = () => { globalThis.__seed = (globalThis.__seed * 1103515245 + 12345) % 2147483648; return globalThis.__seed / 2147483648 };`,
    ctx,
  );
  vm.runInContext(STORE_JS, ctx);
  await vm.runInContext('STORE.open()', ctx);
  ctx.__ids = new Set(VOCAB.map(d => d.l + ':' + d.h));
  vm.runInContext('STORE.migrate({ ids: __ids })', ctx);
  vm.runInContext(PRELUDE, ctx);
  vm.runInContext(LEARN_JS, ctx);
  return { ctx, box, run: c => vm.runInContext(c, ctx), LM: vm.runInContext('LM', ctx) };
}

/* deterministic learner behaviour: FNV-1a of a text, as a number in [0, 1) */
function h01(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h / 4294967296;
}

/* ---------------- the recorder ---------------- */
class Rec {
  constructor(name, saved = {}, { seed = 7, time = Date.UTC(2026, 2, 2, 9), band = false } = {}) {
    this.name = name;
    this.saved = saved;
    this.cfg = { seed, time, band };
    this.ops = [];
  }
  async open() {
    this.s = await sandbox(this.saved, this.cfg);
    this.LM = this.s.LM;
    this.t = this.cfg.time;
    return this;
  }
  op(op, a, o) {
    this.ops.push({ op, a, o: o === undefined ? null : JSON.parse(JSON.stringify(o)) });
    return o;
  }
  word(id) {
    return this.s.run(`IDX.get(${JSON.stringify(id)})`);
  }
  pool(spec) {
    /* spec: {l} a level, {l, u} a unit */
    return this.s.run(`BY[${spec.l}]`).filter(d => spec.u == null || d.u === spec.u);
  }
  advance(min) {
    this.t += min * 6e4;
    this.s.ctx.__T = this.t;
    this.op('advance', { min });
  }
  setTts(on) {
    this.s.ctx.__tts = on;
    this.s.run('LM.setTts(() => !!globalThis.__tts)');
    this.op('tts', { on });
  }
  save() {
    fs.mkdirSync(OUT, { recursive: true });
    const f = path.join(OUT, this.name + '.json');
    fs.writeFileSync(f, JSON.stringify({ name: this.name, ...this.cfg, saved: this.saved, ops: this.ops }));
    console.log(`${this.name}: ${this.ops.length} ops, ${(fs.statSync(f).size / 1024).toFixed(0)} KB`);
  }
}

const items = list => list.map(it => [it.k, it.d.id, it.q || null, it.isNew ? 1 : 0, it.part || null]);
const qmat = m =>
  m.typed ? { typed: 1 } : { o: m.opts.map(x => (Array.isArray(x) ? x.join(' ') : x.id)), ans: m.ans };

/* answer a question the way a learner with knowledge `know` (0–1) would: right or wrong, the pick, the time */
function act(R, it, know, salt) {
  const d = it.d,
    q = it.q;
  const m = R.op('question', { id: d.id, q, hard: it.hard ?? null }, qmat(R.LM.question(d, q, it.hard)));
  const ok = h01(d.id + q + salt) < know;
  let x = 0;
  if (!ok && m.o) {
    const wrong = m.o.map((o, i) => [o, i]).filter(p => p[1] !== m.ans);
    if (wrong.length && q !== 's' && q !== 'cs') x = wrong[Math.floor(h01(salt + d.id) * wrong.length)][0];
  }
  const ms = 1500 + Math.floor(h01(salt + q + d.id + 'ms') * 9000);
  const o = { q, ok, ms };
  if (x && typeof x === 'string' && x.includes(':')) o.x = x;
  R.op('answer', { id: d.id, ...o }, R.LM.answer(d, Object.assign({}, o)));
  return ok;
}

function card(R, it, know, salt) {
  /* the card flow: "I know it" or "Don't know"; a claim may be checked (cm/cs) or trusted (cu) */
  const d = it.d,
    claim = h01(salt + d.id + 'claim') < know + 0.1;
  if (!claim) {
    R.op('answer', { id: d.id, q: 'cn', ok: false, ms: 4000 }, R.LM.answer(d, { q: 'cn', ok: false, ms: 4000 }));
    return;
  }
  const p = R.op('checkP', { id: d.id }, R.LM.checkP(d));
  if (h01(salt + d.id + 'chk') < p) {
    const q = R.op('checkType', { id: d.id }, R.LM.checkType(d, false));
    const m = R.op('question', { id: d.id, q, hard: null }, qmat(R.LM.question(d, q)));
    const ok = h01(d.id + q + salt) < know;
    R.op(
      'answer',
      { id: d.id, q, ok, ms: 3500, claim: true, over: !ok },
      R.LM.answer(d, { q, ok, ms: 3500, claim: true, over: !ok }),
    );
  } else {
    R.op(
      'answer',
      { id: d.id, q: 'cu', ok: true, ms: 2500, claim: true, unchecked: true },
      R.LM.answer(d, { q: 'cu', ok: true, ms: 2500, claim: true, unchecked: true }),
    );
  }
}

function runItems(R, list, know, salt) {
  list.forEach((it, i) => (it.k === 'card' ? card(R, it, know, salt + i) : act(R, it, know, salt + i)));
}

/* everything the screens read, after a day of practice */
function look(R) {
  const L = R.LM;
  const P = L.plan();
  R.op('plan', {}, Object.assign({}, P, { finish: P.finish ? L.isoDay(P.finish) : null, fixDate: P.fixDate ? L.isoDay(P.fixDate) : null }));
  R.op('stage', {}, L.stage());
  R.op('soul', {}, L.soul());
  R.op('streak', {}, L.streak());
  R.op('challenge', {}, L.challenge());
  const A = L.advice();
  R.op('advice', {}, { L: A.L, items: A.items.map(x => Object.assign({}, x, { words: x.words && x.words.map(w => w.id), a: x.a && x.a.id, b: x.b && x.b.id })) });
  R.op('forecast', {}, L.forecast());
  R.op('btChance', {}, L.btChance());
  const I = L.insights();
  R.op('insights', {}, Object.assign({}, I, { pairs: I.pairs.map(p => [p[0].id, p[1].id, p[2]]) }));
  R.op('restGain', {}, L.restGain());
  R.op('sinceLast', {}, L.sinceLast());
  R.op('stability', {}, L.stability());
  R.op('curLevel', {}, { cur: L.curLevel(), base: L.baseLevel(), realm: L.realm(), ptOpen: L.ptOpen(), canTest: L.canTest() });
  R.op('levels', {}, Object.fromEntries(Object.keys(R.s.run('stats')).map(id => [id, L.levelOf(L.mem(id))])));
}

/* ---------------- scenarios ---------------- */
async function fresh() {
  /* a new learner, 24 days of sessions, cards and quizzes on HSK 1, an extra session, a goal */
  const R = await new Rec('fresh').open();
  R.setTts(true);
  look(R);
  for (let day = 0; day < 24; day++) {
    const S = R.op('session', { extra: false }, items(R.LM.session(false)));
    runItems(R, S.map(x => ({ k: x[0], d: R.word(x[1]), q: x[2] })), 0.8, "d" + day);
    if (day % 3 === 1) {
      const pool = R.pool({ l: 1, u: 1 + (day % 5) });
      const C = R.op('cardDeck', { l: 1, u: 1 + (day % 5), n: 12 }, R.LM.cardDeck(pool, 12).map(d => d.id));
      runItems(R, C.map(id => ({ k: 'card', d: R.word(id) })), 0.7, 'c' + day);
    }
    if (day % 4 === 2) {
      const type = [null, 'm', 'f', 's', 'c', 'p', 't', 'l'][day % 8];
      const Q = R.op('quizRound', { l: 1, u: null, n: 12, type }, items(R.LM.quizRound(R.pool({ l: 1 }), 12, type)));
      runItems(R, Q.map(x => ({ k: 'q', d: R.word(x[1]), q: x[2] })), 0.75, 'q' + day);
    }
    if (day === 5) {
      const S2 = R.op('session', { extra: true }, items(R.LM.session(true)));
      runItems(R, S2.map(x => ({ k: x[0], d: R.word(x[1]), q: x[2] })), 0.8, 'x' + day);
    }
    if (day === 6) {
      const g = { t: 'exam', lv: 2, date: '2026-04-20', pace: 'auto' };
      R.op('setGoal', g, R.LM.setGoal(g));
    }
    if (day === 12) {
      R.op('setRest', { a: [0, 3] }, R.LM.setRest([0, 3]));
      R.op('updWeak', {}, R.LM.updWeak());
    }
    if (day === 15) {
      const g = { t: 'level', lv: 3, date: '2026-09-01', pace: 'min', n: 20 };
      R.op('setGoal', g, R.LM.setGoal(g));
    }
    if (day % 6 === 5) look(R);
    R.advance(1440 + ((day * 137) % 300) - 150);
  }
  look(R);
  const E = R.op('exam', { lv: 2, n: 20 }, items(R.LM.exam(2, 20)));
  runItems(R, E.map(x => ({ k: 'q', d: R.word(x[1]), q: x[2] })), 0.7, 'e');
  R.op('modelCheck', {}, R.LM.modelCheck());
  R.op('seqs', {}, R.LM.seqs().length);
  R.op('mem', {}, R.LM.exportMem());
  R.save();
}

async function placement() {
  /* the placement test for a learner who knows HSK 1–3, then the first days at the new realm */
  for (const [name, top, seed] of [
    ['placement3', 3, 11],
    ['placement5', 5, 12],
    ['guesser', 0, 13],
  ]) {
    const R = await new Rec(name, {}, { seed }).open();
    R.setTts(false);
    const st = R.LM.ptStart();
    let it,
      n = 0;
    while ((it = R.LM.ptNext(st))) {
      R.op('ptNext', {}, { id: it.d.id, l: it.l, q: it.q, ...qmat(it) });
      const k = h01(it.d.id + name) < (it.l <= top ? 0.93 : 0.12);
      const r = top === 0 ? (h01('g' + n) < 0.25 ? 'ok' : 'ng') : k ? 'ok' : h01('i' + n + name) < 0.6 ? 'idk' : h01('j' + n) < 0.25 ? 'ok' : 'ng';
      R.LM.ptAnswer(st, it, r);
      R.op('ptAnswer', { r });
      n++;
    }
    const res = R.op('ptResult', {}, R.LM.ptResult(st));
    R.op('placementDone', {}, R.LM.placementDone(res));
    look(R);
    for (let day = 0; day < 6; day++) {
      const S = R.op('session', { extra: false }, items(R.LM.session(false)));
      runItems(R, S.map(x => ({ k: x[0], d: R.word(x[1]), q: x[2] })), 0.85, name + day);
      R.advance(1440);
    }
    look(R);
    R.op('mem', {}, R.LM.exportMem());
    R.save();
  }
}

async function legacy() {
  /* progress from before v1.8 (mm_stats only), as the v1.7 app left it */
  const st = {};
  VOCAB.filter(d => d.l <= 2).forEach((d, i) => {
    if (i % 3 === 0) st[d.l + ':' + d.h] = [i % 7, i % 4, (i * 7) % 21];
    else if (i % 5 === 0) st[d.l + ':' + d.h] = [i % 9, 1];
  });
  const R = await new Rec('legacy', { mm_stats: JSON.stringify(st), hsk16_theme: '"dark"' }, { seed: 21 }).open();
  R.setTts(true);
  R.op('stats', {}, R.s.run('stats'));
  R.op('mem', {}, R.LM.exportMem());
  look(R);
  for (let day = 0; day < 8; day++) {
    const Q = R.op('quizRound', { l: 2, u: null, n: 15, type: null }, items(R.LM.quizRound(R.pool({ l: 2 }), 15, null)));
    runItems(R, Q.map(x => ({ k: 'q', d: R.word(x[1]), q: x[2] })), 0.8, 'L' + day);
    const S = R.op('session', { extra: false }, items(R.LM.session(false)));
    runItems(R, S.map(x => ({ k: x[0], d: R.word(x[1]), q: x[2] })), 0.8, 'S' + day);
    R.advance(1440 * 2);
  }
  look(R);
  R.op('mem', {}, R.LM.exportMem());
  R.save();
}

/* a strong learner made directly in storage: every word of HSK 1..top solid and remembered */
function strongMem(top, t, fade = 1) {
  const mem = {};
  VOCAB.filter(d => d.l <= top).forEach((d, i) => {
    const s = (fade < 1 && d.l === top - 1 ? 3 : 30 + (i % 50)) * fade;
    const at = t - 1440 * (1 + (i % 9));
    const sk = [4, s, at, 3, 2];
    mem[d.l + ':' + d.h] = { w: [4 + (i % 5) * 0.5, s, at], m: sk, f: sk, s: sk, i: at - 1440 * 30, k: at - 1440 * 10 };
  });
  return mem;
}

async function tribulation() {
  const T = Math.round((Date.UTC(2026, 5, 1, 10) - EPOCH) / 6e4);
  const lvl = { r: 2, lv: 2, src: 'test', at: T - 1440 * 30, m: 1, per: [98, 70, 30, 10, 3, 1], th: [1.9, 0.4], pt: [T - 1440 * 30], hist: [[2, T - 1440 * 30, 'test']] };
  for (const [name, know, tts] of [
    ['trib-pass', 0.97, true],
    ['trib-fail', 0.6, false],
  ]) {
    const R = await new Rec(name, { xc_mem: JSON.stringify(strongMem(2, T)), xc_lvl: JSON.stringify(lvl), xc_tests: JSON.stringify([T - 1440 * 30]) }, { seed: 31, time: Date.UTC(2026, 5, 1, 10) }).open();
    R.setTts(tts);
    look(R);
    R.op('btReady', {}, { ready: R.LM.btReady(), open: R.LM.btOpen(), makeup: R.LM.makeupOpen() });
    const st = R.LM.btStart();
    R.op('btStart', {}, { r: st.r, L: st.L, makeup: st.makeup, strikes: st.strikes, items: st.items.map(it => ({ id: it.d.id, q: it.q, strike: it.strike, limit: it.limit || null, ...qmat(it) })) });
    st.items.forEach((it, i) => (it.r = h01(it.d.id + name + i) < know ? 'ok' : 'ng'));
    R.op('btAnswers', { r: st.items.map(it => it.r) });
    const res = R.LM.btFinish(st);
    R.op('btFinish', {}, Object.assign({}, res, { weak: res.weak.map(d => d.id) }));
    R.op('grades', {}, R.LM.grades());
    R.op('level', {}, R.LM.level);
    look(R);
    R.save();
  }
}

async function unstable() {
  /* realm 3 whose HSK 2 has faded: unstable, the stabilising words, the trial */
  const T = Math.round((Date.UTC(2026, 6, 1, 10) - EPOCH) / 6e4);
  const lvl = { r: 3, lv: 3, src: 'bt', at: T - 1440 * 60, hist: [[3, T - 1440 * 60, 'bt', 2]] };
  const R = await new Rec('unstable', { xc_mem: JSON.stringify(strongMem(3, T - 1440 * 40, 0.3)), xc_lvl: JSON.stringify(lvl) }, { seed: 41, time: Date.UTC(2026, 6, 1, 10) }).open();
  R.setTts(true);
  look(R);
  R.op('stabWords', {}, R.LM.stabWords().map(d => d.id));
  R.op('stabDone', { right: 12, total: 15 }, R.LM.stabDone(12, 15));
  R.op('stability', {}, R.LM.stability());
  look(R);
  R.save();
}

async function band() {
  /* past the gate: HSK 7–9 loaded, realm 7 studying HSK 7, the tribulation with a translation strike */
  const T = Math.round((Date.UTC(2026, 8, 1, 10) - EPOCH) / 6e4);
  const lvl = { r: 7, lv: 7, src: 'bt', at: T - 1440 * 20, gate: T - 1440 * 20, gs: 1, hist: [[7, T - 1440 * 20, 'bt', 3]] };
  const mem = strongMem(6, T - 1440 * 5);
  const R = await new Rec('band', { xc_mem: JSON.stringify(mem), xc_lvl: JSON.stringify(lvl) }, { seed: 51, time: Date.UTC(2026, 8, 1, 10), band: true }).open();
  R.setTts(true);
  look(R);
  for (let day = 0; day < 4; day++) {
    const S = R.op('session', { extra: false }, items(R.LM.session(false)));
    runItems(R, S.map(x => ({ k: x[0], d: R.word(x[1]), q: x[2] })), 0.8, 'b' + day);
    R.advance(1440);
  }
  const st = R.LM.btStart();
  R.op('btStart', {}, { r: st.r, L: st.L, makeup: st.makeup, strikes: st.strikes, items: st.items.map(it => ({ id: it.d.id, q: it.q, strike: it.strike, limit: it.limit || null, ...qmat(it) })) });
  for (const L of [7, 3]) {
    const M = R.LM.mockExam(L);
    R.op('mockExam', { L }, { L: M.L, parts: M.parts, sec: M.sec, skipped: M.skipped, items: items(M.items) });
    M.items.forEach((it, i) => (it.ok = h01(it.d.id + 'mock' + i) < 0.7));
    R.op('mockOk', { ok: M.items.map(it => it.ok) });
    const sc = R.op('mockScore', {}, R.LM.mockScore(M));
    R.op('mockSave', { used: 1234.4 }, R.LM.mockSave(M, sc, 1234.4));
  }
  R.op('mocks', {}, R.LM.mocks);
  look(R);
  R.save();
}

async function typed() {
  /* typed pinyin checks */
  const R = await new Rec('typed', {}, { seed: 61 }).open();
  const cases = [
    ['1:学生', ['xue2sheng1', 'xuésheng', 'xueshēng', 'xue2sheng', 'xue sheng', 'xue4sheng1', 'xuěshēng', "xue2'sheng5", 'xu:e', '']],
    ['1:一', ['yi1', 'yí', 'yì', 'yi3', 'yī']],
    ['1:不', ['bu4', 'bú', 'bū', 'bu']],
    ['1:女儿', ['nv3er2', 'nü3ér', 'nu:3er2', 'nǚ ér', 'nuer']],
    ['1:谢谢', ['xie4xie', 'xiè xie', 'xie4xie4', 'xie4xie1', 'xiexie']],
    ['2:已经', ['yi3jing1', 'yǐjīng', 'yijing', 'yi2jing1']],
    ['1:爸爸', ['ba4ba', 'ba4ba4', 'baba', 'bàba']],
    ['1:喜欢', ['xi3huan', 'xǐhuān', 'xihuan1', 'xi3huan1']],
  ];
  for (const [id, inputs] of cases) {
    const d = R.word(id);
    if (!d) continue;
    for (const t of inputs) {
      const r = R.LM.pyCheck(d, t);
      R.op('pyCheck', { id, t }, Object.assign({}, r, { alt: r.alt ? r.alt.id : undefined }));
    }
  }
  /* question material on many words, all types */
  const pick = R.s.run('DATA').filter((d, i) => i % 97 === 0);
  for (const d of pick)
    for (const q of ['m', 'f', 's', 'l', 'c', 't', 'cm', 'cs'])
      R.op('question', { id: d.id, q, hard: q === 'f' ? 0.9 : null }, qmat(R.LM.question(d, q, q === 'f' ? 0.9 : undefined)));
  R.op('wdiff', {}, R.s.run('DATA').filter((d, i) => i % 13 === 0).map(d => [d.id, R.LM.wdiff(d)]));
  R.save();
}

async function optimize() {
  /* a learner with enough spaced reviews to fit the model's parameters */
  const R = await new Rec('optimize', {}, { seed: 71 }).open();
  R.setTts(false);
  for (let day = 0; day < 40; day++) {
    const S = R.op('session', { extra: false }, items(R.LM.session(false)));
    runItems(R, S.map(x => ({ k: x[0], d: R.word(x[1]), q: x[2] })), 0.78, 'o' + day);
    R.advance(1440);
  }
  R.op('seqs', {}, R.LM.seqs().length);
  const res = await R.LM.optimize(true);
  R.op('optimize', {}, Object.assign({}, res, { W: R.LM.params }));
  R.op('modelCheck', {}, R.LM.modelCheck());
  look(R);
  R.save();
}

(async () => {
  for (const f of [typed, fresh, placement, legacy, tribulation, unstable, band, optimize]) await f();
})().catch(e => {
  console.error(e);
  process.exit(1);
});
