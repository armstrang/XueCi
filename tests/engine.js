/* Engine tests: the progress store (schema versions and migrations) and the learning engine (LM), run in Node.

     node tests/engine.js

   Every case gets a fresh sandbox (Node's vm) holding store.js and learn.js with the word data from web/data/vocab.json
   and a stand-in localStorage; there is no IndexedDB in Node, so the store runs on localStorage alone. Time and chance
   are fixed so results repeat. Exits non-zero on any failed check. */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.dirname(__dirname);
const read = (...p) => fs.readFileSync(path.join(ROOT, ...p), 'utf8');
const STORE_JS = read('web', 'src', 'store.js');
const LEARN_JS = read('web', 'src', 'learn.js');
const VOCAB = read('web', 'data', 'vocab.json');
const EPOCH = Date.UTC(2026, 0, 1);

let failed = 0;
function check(cond, what, extra) {
  console.log((cond ? 'ok   ' : 'FAIL ') + what + (extra !== undefined ? '  ' + JSON.stringify(extra) : ''));
  if (!cond) failed++;
}

/* the app's word preparation (app/core.js) and the placement flag build.py adds (data/core.json "pm") */
const PRELUDE = `
/* before the gate only HSK 1–6 are loaded (data/core.json); past it HSK 7–9 too (data/core-b.json) */
const DATA = JSON.parse(__VOCAB).filter(d => __band || d.l <= 6);
DATA.forEach(d => { d.pm = d.m.split(';')[0].length <= 28 ? 1 : 0 });
const LEVELS = [...new Set(DATA.map(d => d.l))].sort((a, b) => a - b);
const BY = {}; LEVELS.forEach(l => BY[l] = DATA.filter(d => d.l === l));
const TONE = {1:'āēīōūǖĀĒĪŌŪ',2:'áéíóúǘÁÉÍÓÚ',3:'ǎěǐǒǔǚǍĚǏǑǓ',4:'àèìòùǜÀÈÌÒÙ'};
const tone = s => { for (const t in TONE) { for (const c of TONE[t]) if (s.includes(c)) return +t } return 5 };
const plain = s => s.normalize('NFD').replace(/\\p{M}/gu, '').replace(/ü/g, 'v').replace(/['\\s]/g, '').toLowerCase();
DATA.forEach(d => { d.id = d.l + ':' + d.h; d.pk = plain(d.p) });
const IDX = new Map(DATA.map(d => [d.id, d]));
const M = d => d.m, M1 = d => M(d).split(";")[0].trim(), TR = d => d.t;
let stats = ls.get('mm_stats', null); if (!stats || typeof stats !== 'object') stats = {};
const saveStats = () => ls.set('mm_stats', stats);
let state = { level: 1, unitBy: { 1: 1 } }; const unit = () => state.unitBy[state.level];
`;

/* a fresh sandbox: localStorage filled with `saved`, the store opened and migrated, then (unless storeOnly) the engine */
async function sandbox(saved = {}, { storeOnly = false, time = Date.UTC(2026, 9, 1, 2), seed = 1, band = false } = {}) {
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
  vm.runInContext(
    `Date.now = () => globalThis.__T;
    Math.random = () => { globalThis.__seed = (globalThis.__seed * 1103515245 + 12345) % 2147483648; return globalThis.__seed / 2147483648 };`,
    ctx,
  );
  vm.runInContext(STORE_JS, ctx, { filename: 'store.js' });
  await vm.runInContext('STORE.open()', ctx);
  const ids = new Set(JSON.parse(VOCAB).map(d => d.l + ':' + d.h));
  ctx.__ids = ids;
  vm.runInContext('STORE.migrate({ ids: __ids })', ctx);
  if (!storeOnly) {
    vm.runInContext(PRELUDE, ctx, { filename: 'prelude.js' });
    vm.runInContext(LEARN_JS, ctx, { filename: 'learn.js' });
  }
  const run = code => vm.runInContext(code, ctx);
  return {
    ctx,
    box,
    run,
    get LM() {
      return run('LM');
    },
    get stats() {
      return run('stats');
    },
    word: h => run(`DATA.find(d => d.h === ${JSON.stringify(h)})`),
    level: l => run(`BY[${l}]`),
    setTime(t) {
      ctx.__T = t;
    },
    advance(days) {
      ctx.__T += days * 864e5;
    },
    min() {
      return Math.round((ctx.__T - EPOCH) / 6e4);
    },
  };
}

/* ---------------- the store ---------------- */
async function storeTests() {
  // schema 1 (up to v1.7): two-number records and the old list of known words
  let s = await sandbox(
    {
      mm_stats: JSON.stringify({ '1:学生': [5, 1], '1:银行': [2, 4, 0], bad: 'x' }),
      hsk16_theme: '"dark"',
    },
    { storeOnly: true },
  );
  let info = s.run('STORE.info()');
  check(
    info.mode === 'ls' && info.from === 1,
    'store: schema 1 data recognised (no IndexedDB in Node → localStorage)',
    info,
  );
  let st = JSON.parse(s.box.get('mm_stats'));
  check(
    JSON.stringify(st['1:学生']) === '[5,1,4]' && JSON.stringify(st['1:银行']) === '[2,4,0]' && !('bad' in st),
    'store: migration 1 → 2 gives every record a level and drops broken ones',
    st,
  );
  check(
    s.box.get('xc_schema') === '3' && s.box.get('hsk16_theme') === '"dark"',
    'store: schema 3 written, other keys untouched',
  );

  s = await sandbox({ hsk16_known: JSON.stringify(['1:学生', '1:nope', '2:已经']) }, { storeOnly: true });
  st = JSON.parse(s.box.get('mm_stats'));
  check(
    Object.keys(st).length === 2 && st['1:学生'] && st['2:已经'] && !st['1:nope'],
    'store: the oldest known-words list is imported (existing words only)',
    st,
  );

  // schema 2 (v1.8–v1.11): nothing to convert
  const v2 = {
    mm_stats: JSON.stringify({ '1:学生': [3, 0, 9] }),
    xc_goal: '{"t":"none","pace":"new","n":10}',
    xc_onb: '1',
  };
  s = await sandbox(v2, { storeOnly: true });
  check(
    s.run('STORE.info().from') === 2 && s.box.get('mm_stats') === v2.mm_stats && s.box.get('xc_goal') === v2.xc_goal,
    'store: schema 2 data kept exactly as it was',
  );

  // fresh install, then a later start finds schema 3 and does nothing
  s = await sandbox({}, { storeOnly: true });
  check(s.run('STORE.info().from') === 3 && s.box.get('xc_schema') === '3', 'store: a fresh start begins at schema 3');
  s = await sandbox({ xc_schema: '3', mm_stats: '{"1:学生":[1,0]}' }, { storeOnly: true });
  check(s.box.get('mm_stats') === '{"1:学生":[1,0]}', 'store: data already at schema 3 is not migrated again');

  // ls wrapper: values round-trip, remove deletes, the localStorage copy follows
  s = await sandbox({}, { storeOnly: true });
  s.run("ls.set('xc_test', {a: [1, 2]}); ls.set('xc_gone', 1); ls.remove('xc_gone')");
  check(
    JSON.stringify(s.run("ls.get('xc_test', null)")) === '{"a":[1,2]}' &&
      s.run("ls.get('xc_gone', 'none')") === 'none' &&
      s.box.get('xc_test') === '{"a":[1,2]}' &&
      !s.box.has('xc_gone'),
    'store: ls get/set/remove, mirrored to localStorage',
  );
}

/* ---------------- the engine ---------------- */
async function engineTests() {
  // FSRS: steady right answers on the due dates grow memory; cramming one day does not
  let s = await sandbox();
  let st = null,
    t = 0;
  const S = [];
  for (const dt of [0, 3, 11, 35, 120]) {
    t += dt * 1440;
    st = s.LM.step(s.LM.W0, st, 3, t, 0);
    S.push(st[1]);
  }
  check(
    S.every((x, i) => !i || x > S[i - 1]) && S[4] > 120,
    'fsrs: stability grows with spaced right answers',
    S.map(x => +x.toFixed(1)),
  );
  st = null;
  for (let i = 0; i < 10; i++) st = s.LM.step(s.LM.W0, st, 3, i * 2, 0);
  check(
    st[1] <= S[0] + 9 * 0.5 + 0.01 && st[1] < S[1],
    'fsrs: ten answers in one sitting add at most half a day each',
    +st[1].toFixed(2),
  );

  // legacy progress (before v1.8): states with the same level, "needs confirming" until a form and a sound answer
  s = await sandbox({
    mm_stats: JSON.stringify({ '1:学生': [25, 1, 20], '1:你好': [10, 0, 10], '2:已经': [16, 0, 16] }),
  });
  check(
    s.stats['1:学生'][2] === 20 && s.LM.mem('1:学生').L === 1,
    'legacy: an old level-20 word keeps its level as "needs confirming"',
  );
  const xs = s.word('学生');
  s.LM.answer(xs, { q: 'f', ok: true, ms: 3000 });
  s.LM.answer(xs, { q: 's', ok: true, ms: 3000 });
  check(s.LM.mem('1:学生').L === 2, 'legacy: a form and a sound answer confirm it');

  // the green gate: meaning alone stops at 13
  const book = s.word('书');
  for (const dt of [0, 3, 10, 30, 60, 120]) {
    s.advance(dt);
    s.LM.answer(book, { q: 'm', ok: true, ms: 3000 });
  }
  const before = s.stats[book.id][2];
  s.LM.answer(book, { q: 'f', ok: true, ms: 3000 });
  s.LM.answer(book, { q: 's', ok: true, ms: 3000 });
  check(before === 13 && s.stats[book.id][2] > 13, 'levels: meaning-only answers stop at 13, form + sound open green', [
    before,
    s.stats[book.id][2],
  ]);

  // "I was wrong" takes back an unchecked claim
  const water = s.word('水'),
    n0 = s.LM.allLog().length;
  s.LM.answer(water, { q: 'cu', ok: true, ms: 2000, claim: true, unchecked: true });
  s.LM.undo();
  check(!s.LM.has(water.id) && s.LM.allLog().length === n0, 'undo: an unchecked claim is taken back completely');

  // placement test: pure guessers land at HSK 1; learners land near their level
  s = await sandbox();
  const place = (p, mode) => {
    const pst = s.LM.ptStart();
    let it;
    while ((it = s.LM.ptNext(pst))) {
      const k = s.run('Math.random()') < p[it.l - 1],
        r = s.run('Math.random()'),
        r2 = s.run('Math.random()');
      s.LM.ptAnswer(
        pst,
        it,
        mode === 'guess'
          ? r < 0.25
            ? 'ok'
            : 'ng'
          : k
            ? r < 0.96
              ? 'ok'
              : 'ng'
            : r < 0.6
              ? 'idk'
              : r2 < 0.25
                ? 'ok'
                : 'ng',
      );
    }
    return s.LM.ptResult(pst);
  };
  const tally = (p, mode, n) => {
    const c = {};
    for (let i = 0; i < n; i++) {
      const o = place(p, mode);
      c[o.lv] = (c[o.lv] || 0) + 1;
    }
    return c;
  };
  const g = tally([0, 0, 0, 0, 0, 0], 'guess', 40);
  check((g[1] || 0) >= 38, 'placement: pure guessers are placed at HSK 1', g);
  const h3 = tally([0.97, 0.93, 0.85, 0.3, 0.08, 0.03], 'honest', 30);
  check((h3[3] || 0) + (h3[4] || 0) >= 27, 'placement: an HSK 1–3 learner is placed at HSK 3 or 4', h3);
  const h6 = tally([0.99, 0.99, 0.97, 0.95, 0.9, 0.85], 'honest', 20);
  check((h6[6] || 0) >= 14, 'placement: a strong learner reaches HSK 6', h6);

  // the placement test counts toward realm progress (v1.12): half of its estimate, until words are solid
  s = await sandbox();
  check(s.LM.stage(1).testShare === 0, 'progress: no test, no test credit');
  s.LM.placementDone({ m: 1, per: [96, 62, 20, 5, 1, 0], mean: 1.7, sd: 0.4 });
  let stg = s.LM.stage();
  check(
    s.LM.realm() === 2 && stg.testShare > 0.1 && stg.testShare <= 0.5 && stg.share === stg.testShare,
    'progress: after the test the realm starts with half the test estimate',
    { share: +stg.share.toFixed(3), test: stg.test },
  );
  const L2 = s.level(2),
    easy = L2.reduce((a, b) => (s.LM.wdiff(a) < s.LM.wdiff(b) ? a : b));
  const share0 = stg.share;
  s.LM.answer(easy, { q: 'f', ok: false, ms: 3000 });
  check(s.LM.stage().share < share0, 'progress: a word answered wrong loses its test credit');
  // v1.9–v1.11 tests kept only the six shares: the ability is fitted to them
  s = await sandbox({
    xc_lvl: JSON.stringify({ lv: 3, r: 3, src: 'test', at: 1000, m: 2, per: [99, 95, 60, 15, 3, 1] }),
  });
  stg = s.LM.stage();
  check(stg.testShare > 0.1, 'progress: an older placement result also gives test credit', +stg.testShare.toFixed(3));

  // 60 days of daily sessions: stage, streak and the five elements stay in range
  s = await sandbox();
  s.LM.placementDone({ m: 0, per: [30, 5, 0, 0, 0, 0], mean: 0.3, sd: 0.4 });
  const startShare = s.LM.stage().share;
  for (let day = 0; day < 60; day++) {
    s.setTime(Date.UTC(2026, 9, 1, 2) + day * 864e5);
    for (const it of s.LM.session(false)) {
      const ok = s.run('Math.random()') < 0.9;
      s.LM.answer(it.d, { q: it.k === 'card' ? (ok ? 'cm' : 'cn') : it.q, ok, ms: 4000, claim: it.k === 'card' && ok });
      s.ctx.__T += 15000;
    }
  }
  const so = s.LM.soul(),
    stk = s.LM.streak();
  check(s.LM.stage().share > startShare + 0.1, 'sim: realm progress grows over 60 days', [
    +startShare.toFixed(3),
    +s.LM.stage().share.toFixed(3),
  ]);
  check(stk.days >= 55, 'sim: 60 days of practice give a long cultivation streak', stk);
  check(
    ['root', 'cult', 'sense', 'dao', 'insight'].every(k => so[k] === null || (so[k] >= 0 && so[k] <= 100)),
    'sim: every element is 0–100',
    so,
  );
  check(
    so.daoN > 300 && so.dao >= 90 && so.sense >= 80,
    'sim: hundreds of honest claims and a learned level earn a high dao and sense',
    { dao: so.dao, n: so.daoN, sense: so.sense },
  );
  const fc = s.LM.forecast();
  check(fc && fc.rate > 0, 'sim: the forecast has a pace', fc);

  // elements need evidence: a handful of right claims and a day of new words are not "full"
  s = await sandbox();
  s.LM.placementDone({ m: 0, per: [10, 0, 0, 0, 0, 0], mean: 0, sd: 0.4 });
  for (const d of s.level(1).slice(0, 20)) {
    s.LM.answer(d, { q: 'cm', ok: true, ms: 3000, claim: true });
    s.ctx.__T += 20000;
  }
  let e = s.LM.soul();
  check(e.dao !== null && e.dao < 80, 'elements: 20 right claims in one day do not fill the dao heart', e.dao);
  check(e.sense !== null && e.sense <= 10, 'elements: 20 new words are a small part of the level’s sense', e.sense);
  // an unchecked claim is verified by the next answer to that word
  const w = s.level(1)[40];
  s.LM.answer(w, { q: 'cu', ok: true, ms: 2000, claim: true, unchecked: true });
  const n1 = s.LM.soul().daoN;
  s.advance(2);
  s.LM.answer(w, { q: 'm', ok: false, ms: 4000 });
  e = s.LM.soul();
  check(
    e.daoN === n1 + 1 && e.daoOk === 20,
    'elements: an unchecked claim is checked by the next answer (wrong here)',
    { n: e.daoN, ok: e.daoOk },
  );

  // breakthrough: all right lifts the realm and uses the week's test
  s = await sandbox();
  s.LM.placementDone({ m: 0, per: [50, 5, 0, 0, 0, 0], mean: 0.6, sd: 0.4 });
  s.advance(8);
  const bt = s.LM.btStart();
  bt.items.forEach(i => {
    i.r = 'ok';
    bt.right++;
  });
  const res = s.LM.btFinish(bt);
  check(
    res.pass && s.LM.realm() === 2 && !s.LM.canTest(),
    'breakthrough: every strike right passes, the realm goes up, next test in a week',
  );
  check(s.LM.level.th[0] >= 1, 'breakthrough: the ability estimate moves up to the proven level', s.LM.level.th);
  s = await sandbox({ xc_lvl: JSON.stringify({ lv: 1, r: 1, src: 'bt', at: 1000 }) });
  const bt2 = s.LM.btStart();
  bt2.items.forEach(i => { i.r = 'ok'; bt2.right++ });
  s.LM.btFinish(bt2);
  check(s.LM.realm() === 2 && !s.LM.level.th && s.LM.stage().testShare === 0, 'breakthrough: without a placement test the next realm has no test credit');

  // card decks: no look-alikes next to each other
  const deck = s.LM.cardDeck(s.level(1), 20);
  let adj = 0;
  for (let i = 1; i < deck.length; i++) {
    const a = deck[i - 1],
      b = deck[i];
    if ([...a.h].some(c => b.h.includes(c)) || a.pk === b.pk) adj++;
  }
  check(deck.length >= 10 && adj === 0, 'cards: shuffled without look-alikes in a row', deck.map(d => d.h).join(' '));

  // backup: study days in the code survive a restore; clearing the history clears them
  s = await sandbox();
  const today = s.LM.dayOf(s.LM.now());
  s.LM.restoreExtra({ days: [today - 2, today - 1, 'x'] });
  check(
    s.LM.studyDays().has(today - 1) && s.LM.streak().days >= 2,
    'backup: restored study days keep the cultivation days',
    s.LM.streak(),
  );
  check(JSON.parse(s.box.get('xc_days')).length === 2, 'backup: study days are saved (only whole day numbers)');
  s.LM.clearLog();
  check(!s.LM.studyDays().size && !s.box.has('xc_days'), 'backup: deleting the history clears them');
}

/* every word of a level solid (level 15, form and sound passed): the realm studying it is at 圆满 */
function solidAll(s, L) {
  s.run(`(() => { const t = LM.now(), m = LM.exportMem();
    for (const d of BY[${L}]) m[d.id] = {w: [4, 40, t - 60], i: t - 30 * 1440, k: t - 20 * 1440, m: [4, 40, t - 60, 3, 2], f: [4, 40, t - 60, 3, 2], s: [4, 40, t - 60, 3, 2]};
    LM.replace(m) })()`);
}
const lvl = (r, extra = {}) =>
  JSON.stringify(Object.assign({ lv: Math.min(9, Math.max(1, r)), r, src: 'bt', at: 1000, hist: [[r, 1000, 'bt']] }, extra));
/* answers a tribulation: `wrong` = {strike: number of wrong answers} */
function finish(s, st, wrong = {}) {
  const left = Object.assign({}, wrong);
  for (const it of st.items) {
    if (left[it.strike] > 0) {
      left[it.strike]--;
      it.r = 'ng';
    } else {
      it.r = 'ok';
      st.right++;
    }
  }
  return s.LM.btFinish(st);
}

/* ---------------- v1.13 ---------------- */
async function v113Tests() {
  // typed pinyin: tone numbers or marks, ü as v or u:, neutral tones free, 一 and 不 in any of their spoken tones
  let s = await sandbox();
  const py = (h, t) => s.LM.pyCheck(s.word(h), t);
  check(
    py('学生', 'xue2sheng').ok && py('学生', 'xue2sheng1').ok && py('学生', 'xuésheng').ok && py('学生', 'XUE2 SHENG').ok,
    'pinyin: numbers, marks, spaces and capitals are accepted; the neutral tone takes any tone',
  );
  check(py('学生', 'xuesheng').toneless && !py('学生', 'xue3sheng').ok, 'pinyin: missing tones are flagged, a wrong tone is wrong');
  check(py('女儿', 'nv3er2').ok && py('女儿', 'nu:3er2').ok && py('女儿', 'nǚ ér').ok, 'pinyin: ü can be typed as v or u:');
  check(
    py('一起', 'yi1qi3').ok && py('一起', 'yi4qi3').ok && !py('一起', 'yi3qi3').ok && py('不客气', 'bu4ke4qi').ok && !py('不客气', 'bu1ke4qi').ok,
    'pinyin: 一 and 不 take their spoken tones',
  );
  check(py('一点儿', 'yi4dian3r').ok && py('学生', '').empty && !py('学生', '学生').ok, 'pinyin: erhua, empty and non-pinyin input');
  const alt = s.run(`(() => { for (const d of DATA) { const x = DATA.find(y => y.id !== d.id && M1(y).toLowerCase() === M1(d).toLowerCase() && y.pk !== d.pk);
    if (x) return [d.id, x.s.join(' ')] } })()`);
  const ar = s.run(`LM.pyCheck(IDX.get(${JSON.stringify(alt[0])}), ${JSON.stringify(alt[1])})`);
  check(ar.ok && ar.alt, 'pinyin: a word with the same first meaning counts as right', alt);

  // the placement test is the way in: a first test, one retake within 14 days, at most 渡劫
  s = await sandbox();
  check(s.LM.ptOpen() === 'first', 'way in: a new learner may take the placement test');
  s.LM.placementDone({ m: 6, per: [100, 100, 100, 99, 98, 95], mean: 6.6, sd: 0.2 });
  check(s.LM.realm() === 6 && s.LM.ptOpen() === 'retake', 'way in: even a perfect test stops at 渡劫, a retake is open', s.LM.realm());
  s.advance(15);
  check(s.LM.ptOpen() === null, 'way in: after 14 days the retake is gone');
  s = await sandbox();
  s.LM.placementDone({ m: 1, per: [90, 40, 5, 0, 0, 0], mean: 1.4, sd: 0.4 });
  s.advance(8);
  s.LM.placementDone({ m: 2, per: [98, 85, 40, 5, 0, 0], mean: 2.4, sd: 0.4 });
  check(s.LM.ptOpen() === null && s.LM.realm() === 3, 'way in: the retake replaces the result and closes the way in');

  // the tribulation: one strike per skill; 听 is left out without a voice; 速 is timed
  s = await sandbox({ xc_lvl: lvl(1) });
  solidAll(s, 1);
  let st = s.LM.btStart();
  const kinds = st.strikes.map(x => x.k + (x.skipped ? '-' : x.n)).join(' ');
  check(
    kinds === 'shi5 yi5 ting- du5 su8' && st.items.length === 23 && st.items.every(i => (i.strike === 'su') === !!i.limit) && st.items.find(i => i.limit).limit === 6,
    'tribulation: 识 忆 读 速 strikes (听 left out without a voice), 6 s per 速 question at HSK 1',
    kinds,
  );
  check(st.items.filter(i => i.q === 'p').length === 5 && st.items.filter(i => i.q === 'c').every(i => s.LM.clozeOK(i.d)), 'tribulation: 忆 types pinyin, 读 uses sentences');
  let r = finish(s, st);
  check(r.pass && r.grade === 3, 'tribulation: all right without 听 is 上品 (完美 needs every strike)', r.grade);
  s = await sandbox({ xc_lvl: lvl(1) });
  s.LM.setTts(() => true);
  solidAll(s, 1);
  st = s.LM.btStart();
  check(st.items.length === 28, 'tribulation: with a voice 听 joins (28 questions)', st.items.length);
  r = finish(s, st);
  check(r.pass && r.grade === 4 && s.LM.grades()[2] === 4, 'tribulation: not one mistake is 完美, kept in the history', r.grade);
  s = await sandbox({ xc_lvl: lvl(1) });
  s.LM.setTts(() => true);
  solidAll(s, 1);
  r = finish(s, s.LM.btStart(), { yi: 2 });
  check(!r.pass && r.acc >= 0.75 && r.strikes.find(x => x.k === 'yi').pass === false, 'tribulation: one weak strike fails it even when the total is enough', +r.acc.toFixed(2));
  s = await sandbox({ xc_lvl: lvl(1) });
  s.LM.setTts(() => true);
  solidAll(s, 1);
  r = finish(s, s.LM.btStart(), { shi: 1, yi: 1, ting: 1, du: 1, su: 2 });
  check(r.pass && r.grade === 1, 'tribulation: just above the cut in every strike is 下品', { acc: +r.acc.toFixed(2), grade: r.grade });
  s = await sandbox({ xc_lvl: lvl(4) });
  solidAll(s, 4);
  st = s.LM.btStart();
  check(st.items.find(i => i.limit).limit === 5 && s.LM.cutOf(4) === 0.75 && s.LM.cutOf(5) === 0.8, 'tribulation: 5 s at HSK 4–6, the cut rises from HSK 5');

  // the gate: hidden before 飞升; a breakthrough from 渡劫 opens it
  s = await sandbox({ xc_lvl: lvl(6) });
  check(
    !s.run('DATA.some(d => d.l > 6)') && s.run('LEVELS.length') === 6 && s.LM.isFinal(7) && !s.LM.gateOpen(),
    'gate: before it HSK 7–9 are not loaded and 飞升 looks like the top',
  );
  solidAll(s, 6);
  r = finish(s, s.LM.btStart());
  check(r.pass && r.gate && s.LM.gateOpen() && s.LM.realm() === 7, 'gate: breaking through to 飞升 opens it');
  s = await sandbox({ xc_lvl: lvl(7) });
  check(s.LM.gateOpen(), 'gate: a 飞升 broken through before v1.13 opens it');
  s = await sandbox({ xc_lvl: lvl(7, { src: 'test', m: 6, hist: [[7, 1000, 'test']] }) });
  check(!s.LM.gateOpen() && s.LM.makeupOpen() && s.LM.btOpen(), 'gate: a 飞升 from the placement test gets a make-up tribulation');
  st = s.LM.btStart();
  check(st.makeup && st.L === 6, 'gate: the make-up tribulation is on HSK 6');
  r = finish(s, st);
  check(r.pass && r.gate && s.LM.gateOpen() && s.LM.realm() === 7 && s.LM.level.hist.slice(-1)[0][2] === 'bt', 'gate: passing it opens the gate');
  s = await sandbox({ xc_lvl: lvl(7, { gate: 2000, gs: 1 }) }, { band: true });
  check(
    s.run('LEVELS.join()') === '1,2,3,4,5,6,7,8,9' && s.run('BY[7].length') > 1000 && !s.LM.isFinal(7) && s.LM.realmLevel(7) === 7 && s.LM.isFinal(10),
    'gate: past it 飞升 studies HSK 7 and 大罗 is the top',
  );
  solidAll(s, 7);
  st = s.LM.btStart();
  check(
    st.strikes.some(x => x.k === 'fan' && x.n === 5) && st.items.filter(i => i.q === 't').length === 5 && st.items.find(i => i.limit).limit === 4 && s.LM.cutOf(7) === 0.85,
    'gate: HSK 7–9 tribulations add 译 translation, 4 s for 速, an 85 % cut',
  );
  r = finish(s, st);
  check(r.pass && s.LM.realm() === 8 && !r.gate, 'gate: past it the realms rise to 真仙');

  // a realm rests on the level below: fading words make it unstable until a stabilising trial
  s = await sandbox({ xc_lvl: lvl(3) });
  const L2w = s.level(2).slice(0, 20);
  for (const d of L2w) s.LM.answer(d, { q: 'm', ok: true, ms: 3000 });
  s.advance(2);
  for (const d of L2w) s.LM.answer(d, { q: 'm', ok: false, ms: 5000 });
  solidAll(s, 3);
  const sb = s.LM.stability();
  check(!sb.ok && sb.why === 'acc' && sb.P === 2 && s.LM.stage().i === 3 && !s.LM.btOpen(), 'stability: HSK 2 fading makes 金丹 unstable and locks the breakthrough', {
    n: sb.n,
    acc: sb.acc,
  });
  check(s.LM.stabWords().length === 15 && s.LM.stabWords().every(d => d.l === 2), 'stability: the trial takes the 15 most faded HSK 2 words');
  check(!s.LM.stabDone(11, 15) && s.LM.stabDone(12, 15) && s.LM.stability().ok && s.LM.btOpen(), 'stability: 80 % steadies the realm and the breakthrough opens again');

  // model accuracy: predicted recall against what happened
  s = await sandbox();
  for (let day = 0; day < 40; day++) {
    s.setTime(Date.UTC(2026, 9, 1, 2) + day * 864e5);
    for (const it of s.LM.session(false)) {
      s.LM.answer(it.d, { q: it.k === 'card' ? 'cm' : it.q, ok: s.run('Math.random()') < 0.85, ms: 4000, claim: it.k === 'card' });
      s.ctx.__T += 15000;
    }
  }
  const mc = s.LM.modelCheck();
  check(mc.n > 100 && mc.ece >= 0 && mc.ece < 0.3 && mc.bins.length >= 1 && mc.pred > 0 && mc.real > 0.6, 'model check: calibration bins from the spaced reviews', {
    n: mc.n,
    pred: +mc.pred.toFixed(2),
    real: +mc.real.toFixed(2),
    ece: +mc.ece.toFixed(3),
  });
  const fit = await s.LM.optimize(false);
  check(fit !== null && s.LM.params && s.LM.params.length === 19, 'optimizer: fits from 100 spaced reviews (was 400)', mc.n);
}

module.exports = { sandbox };
if (require.main === module)
  (async () => {
    await storeTests();
    await engineTests();
    await v113Tests();
    console.log(failed ? `\n${failed} check(s) failed` : '\nall engine checks passed');
    process.exit(failed ? 1 : 0);
  })().catch(e => {
    console.error(e);
    process.exit(1);
  });
