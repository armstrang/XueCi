/* ================= Learning engine =================
   Everything below runs on the phone. Nothing is sent anywhere.

   Memory model: FSRS-5 (open-source spaced-repetition model, default parameters fitted on public review data).
   A memory state is [difficulty 1–10, stability in days, last answer in minutes since 1 Jan 2026 UTC]; the chance
   of still recalling after t days is R = (1 + 19/81·t/S)^-0.5, so R = 90 % when t = S.
   Every word has one state for the word (drives scheduling and the 0–20 level) plus one per skill:
     m = meaning (see hanzi → meaning), f = form (meaning → hanzi, sentence gap), s = sound (tones/pinyin, listening).
   Skills decide which kind of question comes next and show weaknesses.

   Level 0–20 = how long the word is expected to stay remembered: 20·ln(1+S)/ln(121), so about 1 month → 14 (green)
   and 4 months → 20. Green also needs a passed form (f) and sound (s) answer. Same-day repeats add at most
   half a day of stability, so a word can't be crammed to green in one sitting.

   Storage (through `ls`, the progress store in store.js: IndexedDB on this device, with a localStorage copy; the old
   keys mm_stats/hsk16_* are untouched):
     xc_mem   {id: {w:[d,s,t], m|f|s:[d,s,t,lastGrade,timesRight], i:firstSeen, L:1 legacy unconfirmed|2 confirmed, p:1 first seen in exam practice}}
     xc_log   recent answers, xc_logA older answers (capped): [t, id, type, grade 1–4, tenths of a second, wrong pick id|0, flags]
              flags: 1 unchecked claim, 2 said "I know", 4 sure but wrong, 8 exam practice or breakthrough, 16 placement test,
                     32 translation shown before answering (no skill credit, at most "Hard")
     xc_goal  {t:'level'|'exam'|'none', lv, date:'YYYY-MM-DD', pace:'min'|'new'|'auto', n}
     xc_lvl   {r: realm 0–7, lv: HSK 1–6, src:'test'|'bt'|'manual' (v1.9), at, m: mastered level, per:[6 shares],
              th:[ability, its spread] from the placement test (v1.12), hist:[[realm, time]]}
              the realm (cultivation level) and the level the guided plan starts at; it moves on by itself once every
              word of a level has been introduced
     xc_tests times of the placement tests and breakthroughs (one a week)
     xc_days  study days brought back by a backup code (day numbers), so the cultivation days survive a restore
     xc_rest  meditation weekdays (0 Sunday … 6 Saturday, at most 2) · xc_game {chal: today's challenge, chalN: challenges done}
     xc_amb   sentence-gap pairs the learner reported as both fitting
     xc_w     {w:[19 parameters], n, at, ll, ll0}   parameters fitted to this learner's own answers (optimize())
   Progress made before this engine existed is kept: each old [right, wrong, level] becomes a state with the same
   level, marked "needs confirming" (L:1) until one form and one sound question have been answered. */
const LM = (() => {
  const EPOCH = Date.UTC(2026, 0, 1);
  const now = () => Math.round((Date.now() - EPOCH) / 6e4);
  const TZ = new Date().getTimezoneOffset();
  const dayOf = t => Math.floor((t - TZ) / 1440);
  const cl = (x, a, b) => Math.min(b, Math.max(a, x));
  /* A word's difficulty inside its HSK level, from how common it is in written Chinese (field f, Zipf frequency from
   jieba's dictionary) and whether it brings characters that are new at its level: −0.6 (easy) … +0.6 (hard). */
  let WD = null;
  function wdiff(d) {
    if (!WD) {
      WD = new Map();
      const seen = new Set();
      for (const l of LEVELS) {
        const W = BY[l],
          nov = W.map(x => {
            const c = [...x.h];
            return c.filter(y => !seen.has(y)).length / c.length;
          }),
          fm = W.reduce((a, x) => a + (x.f || 0), 0) / W.length,
          fs = Math.sqrt(W.reduce((a, x) => a + ((x.f || fm) - fm) ** 2, 0) / W.length) || 1,
          nm = nov.reduce((a, b) => a + b, 0) / W.length;
        W.forEach((x, i) => WD.set(x.id, cl((-0.28 * ((x.f || fm) - fm)) / fs + 0.35 * (nov[i] - nm), -0.6, 0.6)));
        W.forEach(x => {
          for (const c of x.h) seen.add(c);
        });
      }
    }
    return WD.get(d.id) || 0;
  }
  const r2 = x => Math.round(x * 100) / 100,
    r3 = x => Math.round(x * 1000) / 1000;

  /* ---- FSRS-5 ---- */
  const W0 = [
    0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605,
    2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
  ];
  const LB = [0.01, 0.01, 0.01, 0.01, 1, 0.001, 0.001, 0.001, 0, 0, 0.001, 0.001, 0.001, 0.001, 0, 0, 1, 0, 0];
  const UB = [100, 100, 100, 100, 10, 4, 4, 0.75, 4.5, 0.8, 3.5, 5, 0.25, 0.9, 4, 1, 6, 2, 2];
  const DECAY = -0.5,
    FACTOR = 19 / 81;
  const Rt = (days, s) => Math.pow(1 + (FACTOR * Math.max(0, days)) / s, DECAY);
  const ivl = (s, r) => (s / FACTOR) * (Math.pow(r, 1 / DECAY) - 1);
  const D0 = (w, g) => cl(w[4] - Math.exp(w[5] * (g - 1)) + 1, 1, 10);
  const sameDay = (t, t0) => t - t0 < 240 || dayOf(t) === dayOf(t0);
  /* st = [d, s, t] or null for a first answer; prior = share of the word's characters already known (0–1);
   dd = the word's own difficulty within its level (−0.6 easy … +0.6 hard, see wdiff) */
  function step(w, st, g, t, prior, dd) {
    if (!st) {
      const k = prior || 0,
        x = dd || 0;
      return [
        cl(D0(w, g) - (g > 1 ? 1.2 * k : 0) + 1.5 * x, 1, 10),
        Math.max(0.1, w[g - 1] * (g > 2 ? 1 + 0.6 * k : 1) * (1 - 0.35 * x)),
        t,
      ];
    }
    const d = st[0],
      s = st[1],
      el = (t - st[2]) / 1440;
    const d2 = cl(w[7] * D0(w, 4) + (1 - w[7]) * (d - (w[6] * (g - 3) * (10 - d)) / 9), 1, 10);
    let s2;
    if (sameDay(t, st[2])) {
      const inc = Math.exp(w[17] * (g - 3 + w[18]));
      s2 = g > 2 ? Math.min(s * inc, s + 0.5) : s * inc;
    } else {
      const r = Rt(el, s);
      s2 =
        g === 1
          ? Math.min(
              w[11] * Math.pow(d, -w[12]) * (Math.pow(s + 1, w[13]) - 1) * Math.exp(w[14] * (1 - r)),
              s / Math.exp(w[17] * w[18]),
            )
          : s *
            (1 +
              Math.exp(w[8]) *
                (11 - d) *
                Math.pow(s, -w[9]) *
                (Math.exp(w[10] * (1 - r)) - 1) *
                (g === 2 ? w[15] : 1) *
                (g === 4 ? w[16] : 1));
    }
    return [d2, cl(s2, 0.1, 36500), t];
  }

  /* ---- storage ---- */
  let W = W0.slice(),
    wMeta = null;
  {
    const o = ls.get('xc_w', null);
    if (o && Array.isArray(o.w) && o.w.length === 19 && o.w.every(Number.isFinite)) {
      W = o.w;
      wMeta = o;
    }
  }
  let mem = ls.get('xc_mem', null);
  if (!mem || typeof mem !== 'object' || Array.isArray(mem)) mem = {};
  let goal = ls.get('xc_goal', null);
  if (!validGoal(goal)) goal = null;
  let logR = ls.get('xc_log', []),
    logA = ls.get('xc_logA', []);
  if (!Array.isArray(logR)) logR = [];
  if (!Array.isArray(logA)) logA = [];
  let logCache = null,
    confMap = null,
    charS = null;
  const allLog = () => logCache || (logCache = logA.length ? logA.concat(logR) : logR.slice());
  function logPush(e) {
    logR.push(e);
    if (logR.length >= 2000) {
      logA = logA.concat(logR).slice(-28000);
      ls.set('xc_logA', logA);
      logR = [];
    }
    ls.set('xc_log', logR);
    logCache = null;
  }
  let saveT = 0;
  function flush() {
    clearTimeout(saveT);
    saveT = 0;
    ls.set('xc_mem', mem);
  }
  const saveMem = () => {
    clearTimeout(saveT);
    saveT = setTimeout(flush, 300);
  };
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && saveT) flush();
  });
  addEventListener('pagehide', () => {
    if (saveT) flush();
  });

  const okS = se => !!se && se[3] > 1;
  const LN121 = Math.log(121);
  function levelOf(e) {
    if (!e || !e.w) return -1;
    let L = cl(Math.round((20 * Math.log(1 + e.w[1])) / LN121), 0, 20);
    if (L > 13 && e.L !== 1 && !(okS(e.f) && okS(e.s))) L = 13;
    return L;
  }
  /* a solid word (kata kokoh): level 10+ (remembered for about a week) and a passed recall and tone question */
  const solid = e => !!e && levelOf(e) >= 10 && okS(e.f) && okS(e.s);
  const skLevel = se => (se ? cl(Math.round((20 * Math.log(1 + se[1])) / LN121), 0, 20) : -1);
  const isState = a =>
    Array.isArray(a) && a.length >= 3 && a.slice(0, 3).every(Number.isFinite) && a[0] >= 1 && a[0] <= 10 && a[1] > 0;
  function cleanEntry(e) {
    if (!e || typeof e !== 'object' || !isState(e.w)) return null;
    const o = { w: [r2(e.w[0]), r3(e.w[1]), Math.round(e.w[2])], i: Number.isFinite(e.i) ? Math.round(e.i) : 0 };
    for (const k of ['m', 'f', 's'])
      if (isState(e[k]))
        o[k] = [r2(e[k][0]), r3(e[k][1]), Math.round(e[k][2]), cl(e[k][3] | 0, 1, 4), Math.max(0, e[k][4] | 0)];
    if (e.L === 1 || e.L === 2) o.L = e.L;
    if (e.p === 1) o.p = 1;
    if (Number.isFinite(e.k)) o.k = Math.round(e.k);
    return o;
  }
  for (const id in mem) {
    const c = IDX.has(id) ? cleanEntry(mem[id]) : null;
    if (c) mem[id] = c;
    else delete mem[id];
  }

  /* Keep the old per-word records (stats) and the memory states in step: old progress becomes a state with the
   same level ("needs confirming"); every level is recalculated from the state. */
  function sync() {
    const t = now();
    for (const id in stats) {
      const e = stats[id];
      if (!IDX.has(id) || e[0] + e[1] <= 0 || mem[id]) continue;
      const L = cl(e[2] | 0, 0, 20),
        S = Math.max(0.1, Math.pow(121, L / 20) - 1),
        D = cl(4 + (6 * e[1]) / Math.max(1, e[0] + e[1]), 1, 10);
      mem[id] = { w: [r2(D), r3(S), t], i: 0, L: 1 };
    }
    for (const id in mem) {
      const st = stats[id] || (stats[id] = [0, 0, 0]);
      st[2] = Math.max(0, levelOf(mem[id]));
    }
    charS = null;
    flush();
    saveStats();
  }

  /* ---- answering ---- */
  /* question types: m meaning · f form (hanzi from meaning) · s tones · l listening · c sentence gap ·
     p type the pinyin from memory (v1.13, production) · t choose the translation of a sentence (v1.13) */
  const SK = { cm: 'm', cs: 's', cn: 'm', m: 'm', f: 'f', s: 's', l: 's', c: 'f', p: 'f', t: 'm' };
  const DEFMS = {
    cm: 4500,
    cs: 4500,
    cu: 4500,
    cn: 4500,
    m: 5000,
    f: 6000,
    s: 6000,
    l: 7000,
    c: 9000,
    p: 15000,
    t: 12000,
  };
  const QUIZ = new Set(['m', 'f', 's', 'l', 'c', 'p', 't']);
  let last = null;
  function medMs(q) {
    const L = allLog(),
      a = [];
    for (let i = L.length - 1; i >= 0 && a.length < 40 && i > L.length - 800; i--) {
      const e = L[i];
      if (e[2] === q && e[3] > 1) a.push(e[4] * 100);
    }
    if (a.length < 8) return DEFMS[q] || 6000;
    a.sort((x, y) => x - y);
    return a[a.length >> 1];
  }
  function grade(o, e) {
    const med = medMs(o.q);
    let g = o.ms <= med * 1.8 && !o.hint ? 3 : 2;
    if (g === 3 && o.ms < med * 0.6 && e.w && e.w[1] >= 3 && !/^(m|cm|cu)$/.test(o.q)) g = 4;
    return g;
  }
  function knownShare(d) {
    if (!charS) {
      charS = new Map();
      for (const id in mem) {
        const x = IDX.get(id),
          s = mem[id].w[1];
        for (const c of x.h) {
          if ((charS.get(c) || 0) < s) charS.set(c, s);
        }
      }
    }
    const cs = [...new Set(d.h)];
    return cs.filter(c => (charS.get(c) || 0) >= 2).length / cs.length;
  }
  /* o: {q: type, ok, ms, x: wrong pick id, claim, over: sure but wrong, unchecked, exam} */
  function answer(d, o) {
    const t = now(),
      id = d.id,
      had = mem[id];
    if (o.placement) o.exam = true;
    const flags =
        (o.unchecked ? 1 : 0) |
        (o.claim ? 2 : 0) |
        (o.over ? 4 : 0) |
        (o.exam ? 8 : 0) |
        (o.placement ? 16 : 0) |
        (o.hint ? 32 : 0),
      ms = Math.min(9999, Math.round((o.ms || 0) / 100));
    if (o.exam && !had && !o.ok) {
      logPush([t, id, o.q, 1, ms, o.x || 0, flags]);
      if (o.x) addConf(id, o.x);
      return { g: 1, before: -1, after: -1 };
    }
    last = {
      id,
      mem: had ? JSON.parse(JSON.stringify(had)) : null,
      st: stats[id] ? stats[id].slice() : null,
      n: logR.length,
    };
    const e = had || { i: t },
      before = levelOf(had),
      g = o.ok ? grade(o, e) : 1;
    if (!had && o.exam) e.p = 1; /* known already (exam practice): not one of today's new words */
    e.w = step(W, e.w, g, t, had ? 0 : knownShare(d), had ? 0 : wdiff(d));
    if (o.over) e.w[0] = Math.min(10, e.w[0] + 1); /* sure but wrong: the word becomes harder */
    e.w = [r2(e.w[0]), r3(e.w[1]), t];
    const k = o.unchecked || o.hint ? null : SK[o.q];
    if (k) {
      const se = e[k],
        ns = step(W, se ? se.slice(0, 3) : null, g, t, 0);
      e[k] = [r2(ns[0]), r3(ns[1]), t, g, (se ? se[4] : 0) + (g > 1 ? 1 : 0)];
    }
    if (e.L === 1 && e.f && e.s) e.L = 2;
    if (!e.k && solid(e)) e.k = t; /* first time the word became solid (for 悟性, how fast you learn) */
    mem[id] = e;
    const st = stats[id] || [0, 0, 0];
    if (o.ok) st[0]++;
    else st[1]++;
    st[2] = levelOf(e);
    stats[id] = st;
    logPush([t, id, o.q, g, ms, o.x || 0, flags]);
    if (o.x) addConf(id, o.x);
    if (!had) charS = null;
    saveMem();
    saveStats();
    return { g, before, after: st[2] };
  }
  /* "Turns out I was wrong" right after an unchecked claim: take that answer back */
  function undo() {
    if (!last) return false;
    const L = last;
    last = null;
    if (L.mem) mem[L.id] = L.mem;
    else delete mem[L.id];
    if (L.st) stats[L.id] = L.st;
    else delete stats[L.id];
    if (logR.length > L.n) {
      logR.length = L.n;
      ls.set('xc_log', logR);
      logCache = null;
    }
    charS = null;
    confMap = null;
    saveMem();
    saveStats();
    return true;
  }

  /* sentence-gap pairs the learner reported as both fitting: never offered together again */
  let amb = new Set(ls.get('xc_amb', []));
  function markAmbiguous(a, b) {
    amb.add(pairKey(a, b));
    ls.set('xc_amb', [...amb].slice(-500));
  }
  /* ---- confusions: which words get mixed up (from wrong picks) ---- */
  const pairKey = (a, b) => (a < b ? a + '|' + b : b + '|' + a);
  function confs() {
    if (!confMap) {
      confMap = new Map();
      for (const e of allLog())
        if (e[5] && IDX.has(e[5])) {
          const k = pairKey(e[1], e[5]);
          confMap.set(k, (confMap.get(k) || 0) + 1);
        }
    }
    return confMap;
  }
  function addConf(a, b) {
    if (!confMap || !IDX.has(b)) return;
    const k = pairKey(a, b);
    confMap.set(k, (confMap.get(k) || 0) + 1);
  }
  function partners(id) {
    const out = [];
    for (const [k, n] of confs()) {
      const [a, b] = k.split('|');
      if (a === id) out.push([b, n]);
      else if (b === id) out.push([a, n]);
    }
    return out.sort((x, y) => y[1] - x[1]).map(x => x[0]);
  }

  /* ---- calibration: how often "I know" turned out right; honest learners get fewer checks ---- */
  function calib() {
    const L = allLog();
    let n = 0,
      c = 0;
    for (let i = L.length - 1; i >= 0 && n < 40; i--) {
      const e = L[i];
      if (e[2] === 'cm' || e[2] === 'cs') {
        n++;
        if (e[3] > 1) c++;
      }
    }
    return { n, acc: n ? c / n : 0 };
  }
  function checkP(d) {
    const e = mem[d.id];
    if (!e || e.L === 1 || !(e.m || e.s)) return 1;
    const c = calib();
    if (c.n < 8) return 1;
    return cl((1 - c.acc) * 4 + 0.25, 0.25, 1);
  }
  function checkType(d, heard) {
    const e = mem[d.id],
      t = now();
    if (heard || !e || !okS(e.m)) return 'cm';
    const r = se => (se ? Rt((t - se[2]) / 1440, se[1]) : 0);
    return r(e.s) < r(e.m) ? 'cs' : 'cm';
  }

  /* ---- question material ---- */
  let IX = null;
  function ix() {
    if (IX) return IX;
    const byChar = new Map(),
      byPk = new Map(),
      push = (m, k, v) => {
        let a = m.get(k);
        if (!a) m.set(k, (a = []));
        a.push(v);
      };
    DATA.forEach(d => {
      for (const c of new Set(d.h)) push(byChar, c, d);
      push(byPk, d.pk, d);
    });
    return (IX = { byChar, byPk });
  }
  const fullPy = d => d.p.toLowerCase().replace(/['\s]/g, '');
  function similar(d) {
    const { byChar, byPk } = ix(),
      out = [],
      seen = new Set([d.id]);
    const add = x => {
      if (x && !seen.has(x.id)) {
        seen.add(x.id);
        out.push(x);
      }
    };
    partners(d.id).forEach(id => add(IDX.get(id)));
    (byPk.get(d.pk) || []).forEach(add);
    const sh = [];
    for (const c of new Set(d.h)) for (const x of byChar.get(c) || []) if (!seen.has(x.id)) sh.push(x);
    const n = [...d.h].length,
      sc = x => Math.abs([...x.h].length - n) * 2 + Math.abs(x.l - d.l) + Math.random();
    [...new Set(sh)]
      .map(x => [sc(x), x])
      .sort((a, b) => a[0] - b[0])
      .forEach(p => add(p[1]));
    return out;
  }
  function recentAcc() {
    const L = allLog();
    let n = 0,
      c = 0;
    for (let i = L.length - 1; i >= 0 && n < 30; i--) {
      const e = L[i];
      if (QUIZ.has(e[2]) && !(e[6] & 8)) {
        n++;
        if (e[3] > 1) c++;
      }
    }
    return { n, acc: n ? c / n : 0 };
  }
  /* how often a wrong option is a look-alike: more for words you know better, adjusted to keep you near 80–85 % right */
  function hardness(d) {
    const L = levelOf(mem[d.id]);
    let h = L < 0 ? 0.15 : L < 7 ? 0.3 : L < 14 ? 0.6 : 0.85;
    const a = recentAcc();
    if (a.n >= 10) {
      if (a.acc > 0.88) h += 0.15;
      else if (a.acc < 0.72) h -= 0.25;
    }
    return cl(h, 0, 1);
  }
  function shuf(a) {
    a = a.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = (Math.random() * (i + 1)) | 0;
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }
  /* four options: the word plus three others (wrong options never share the word's meaning, and never sound the same in a listening question) */
  function wordOpts(d, type, hard) {
    const used = new Set([type === 'm' ? M1(d).toLowerCase() : d.h]),
      fp = fullPy(d),
      picks = [];
    const dm = M1(d).toLowerCase();
    const okX = x => {
      if (x.id === d.id) return false;
      if (type === 'm') {
        const m = M1(x).toLowerCase();
        return !!m && !used.has(m);
      }
      if (used.has(x.h)) return false;
      if (type === 'l' && fullPy(x) === fp) return false;
      const xm = M1(x).toLowerCase();
      if (xm === dm || (xm.length > 2 && dm.length > 2 && (xm.includes(dm) || dm.includes(xm))))
        return false; /* near-synonyms would make two right answers */
      return true;
    };
    const take = x => {
      picks.push(x);
      used.add(type === 'm' ? M1(x).toLowerCase() : x.h);
    };
    const h = type === 'c' ? 0 : hard != null ? hard : hardness(d),
      sim = type === 'c' ? [] : similar(d),
      n = [...d.h].length;
    const near = BY[d.l].filter(x => Math.abs(x.u - d.u) <= 3);
    const sameClass = x =>
      type === 'c' && d.g && x.g && x.g[0] === d.g[0]
        ? 0
        : type === 'c'
          ? 1.2
          : 0; /* sentence gaps: options of the same word class */
    const rnd = shuf(near.length >= 12 ? near : BY[d.l])
      .filter(x => !amb.has(pairKey(d.id, x.id)))
      .map(x => [(type === 'm' ? 0 : Math.abs([...x.h].length - n)) + sameClass(x) + Math.random() * 1.5, x])
      .sort((a, b) => a[0] - b[0])
      .map(p => p[1]);
    let si = 0,
      ri = 0;
    while (picks.length < 3 && (si < sim.length || ri < rnd.length)) {
      let x = null;
      if (Math.random() < h)
        while (si < sim.length && !x) {
          const c = sim[si++];
          if (okX(c)) x = c;
        }
      while (!x && ri < rnd.length) {
        const c = rnd[ri++];
        if (okX(c)) x = c;
      }
      while (!x && si < sim.length) {
        const c = sim[si++];
        if (okX(c)) x = c;
      }
      if (x) take(x);
      else break;
    }
    return shuf([d, ...picks]);
  }
  /* tone options: the word's pinyin plus three versions with other tones. 一 and 不 (tone changes) and neutral-tone
   syllables (many also have a dictionary tone, e.g. 出来 chūlai/chūlái) keep theirs, unless nothing else can change */
  const MARKS = { a: 'āáǎà', e: 'ēéěè', i: 'īíǐì', o: 'ōóǒò', u: 'ūúǔù', ü: 'ǖǘǚǜ' };
  const bareSyl = s => s.normalize('NFD').replace(/[̀́̄̌]/g, '').normalize('NFC');
  function markTone(p, t) {
    if (t === 5) return p;
    const low = p.toLowerCase();
    let i = low.indexOf('a');
    if (i < 0) i = low.indexOf('e');
    if (i < 0 && low.includes('ou')) i = low.indexOf('o');
    if (i < 0)
      for (let j = low.length - 1; j >= 0; j--)
        if ('iouü'.includes(low[j])) {
          i = j;
          break;
        }
    if (i < 0) return p;
    const ch = low[i],
      m = MARKS[ch];
    if (!m) return p;
    let r = m[t - 1];
    if (p[i] !== ch) r = r.toUpperCase();
    return p.slice(0, i) + r + p.slice(i + 1);
  }
  const NEAR = { 1: [4, 2, 3], 2: [3, 1, 4], 3: [2, 4, 1], 4: [1, 3, 2], 5: [4, 1, 3] };
  function toneOpts(d) {
    const syl = d.s,
      ch = [...d.h],
      key = a => a.join(' '),
      seen = new Set([key(syl)]),
      out = [];
    const can = i => markTone(bareSyl(syl[i]), 1) !== bareSyl(syl[i]);
    let idx = syl
      .map((_, i) => i)
      .filter(i => can(i) && tone(syl[i]) !== 5 && !(syl.length === ch.length && (ch[i] === '一' || ch[i] === '不')));
    if (!idx.length) idx = syl.map((_, i) => i).filter(can);
    const vary = (a, i, t) => {
      const b = a.slice();
      b[i] = markTone(bareSyl(a[i]), t);
      return b;
    };
    const near = [],
      far = [];
    for (const i of idx) {
      const N = NEAR[tone(syl[i])];
      near.push(vary(syl, i, N[0]), vary(syl, i, N[1]));
      far.push(vary(syl, i, N[2]));
    }
    for (let k = 0; k < 16 && idx.length > 1; k++) {
      const i = idx[(Math.random() * idx.length) | 0],
        j = idx[(Math.random() * idx.length) | 0];
      if (i === j) continue;
      far.push(
        vary(vary(syl, i, NEAR[tone(syl[i])][(Math.random() * 2) | 0]), j, NEAR[tone(syl[j])][(Math.random() * 2) | 0]),
      );
    }
    for (const v of shuf(near).concat(shuf(far))) {
      if (out.length === 3) break;
      const k = key(v);
      if (!seen.has(k)) {
        seen.add(k);
        out.push(v);
      }
    }
    const opts = shuf([syl, ...out]);
    return { opts, ans: opts.indexOf(syl) };
  }
  const clozeOK = d => !!d.z && d.z.includes(d.h);
  let ttsReady = () => false;
  /* the translation of an example sentence: the right one and three of other words' sentences, preferring words
     that look or sound alike, then sentences of about the same length (a short exclamation among long sentences
     gives itself away), so the sentences have to be read, not guessed from length or one familiar word */
  function transOpts(d, hard) {
    const tr = x => (TR(x) || '').trim(),
      own = tr(d),
      used = new Set([own]),
      picks = [],
      len = own.length || 1;
    const sim = Math.random() < (hard != null ? hard : 0.6) ? similar(d) : [];
    const near = BY[d.l]
      .filter(x => Math.abs(x.u - d.u) <= 4)
      .map(x => [Math.abs(tr(x).length - len) / len + Math.random() * 0.25, x])
      .sort((a, b) => a[0] - b[0])
      .map(p => p[1]);
    for (const x of sim.concat(near, shuf(BY[d.l]))) {
      if (picks.length === 3) break;
      const t = tr(x);
      if (x.id === d.id || !t || used.has(t) || !clozeOK(x)) continue;
      used.add(t);
      picks.push(x);
    }
    const opts = shuf([d, ...picks]);
    return { opts, ans: opts.indexOf(d) };
  }
  /* material for one question: {opts, ans} — ans is the index of the right option; a typed question has no options */
  function question(d, q, hard) {
    if (q === 's' || q === 'cs') return toneOpts(d);
    if (q === 'p') return { opts: null, ans: -1, typed: true };
    if (q === 't') return transOpts(d, hard);
    const opts = wordOpts(d, q === 'cm' ? 'm' : q, hard);
    return { opts, ans: opts.indexOf(d) };
  }
  /* ---- typed pinyin ----
     Accepts tone numbers (xue2sheng1; the neutral tone as 5, 0 or nothing) or tone marks (xuéshēng), ü as ü, v or u:,
     with or without spaces and apostrophes. The letters must match exactly and every syllable's tone must be right,
     except: a neutral-tone syllable accepts any tone (many have a dictionary tone too), and 一 / 不 accept their own
     tone as well as the changed one (yī / yí / yì, bù / bú). Another word with the same first meaning counts as right. */
  const TONED = {
    ā: ['a', 1],
    á: ['a', 2],
    ǎ: ['a', 3],
    à: ['a', 4],
    ē: ['e', 1],
    é: ['e', 2],
    ě: ['e', 3],
    è: ['e', 4],
    ī: ['i', 1],
    í: ['i', 2],
    ǐ: ['i', 3],
    ì: ['i', 4],
    ō: ['o', 1],
    ó: ['o', 2],
    ǒ: ['o', 3],
    ò: ['o', 4],
    ū: ['u', 1],
    ú: ['u', 2],
    ǔ: ['u', 3],
    ù: ['u', 4],
    ǖ: ['v', 1],
    ǘ: ['v', 2],
    ǚ: ['v', 3],
    ǜ: ['v', 4],
    ü: ['v', 0],
  };
  function pyParse(text) {
    const s = String(text || '')
      .normalize('NFC')
      .toLowerCase()
      .replace(/u:/g, 'v')
      .replace(/[\s'’\-·]/g, '');
    let letters = '';
    const tones = [];
    for (const ch of s) {
      if (TONED[ch]) {
        letters += TONED[ch][0];
        if (TONED[ch][1]) tones[letters.length - 1] = TONED[ch][1];
      } else if (/[0-5]/.test(ch)) {
        if (letters.length) tones[letters.length - 1] = +ch || 5;
      } else if (/[a-z]/.test(ch)) letters += ch;
      else return null;
    }
    return { letters, tones };
  }
  function pyCheck(d, text) {
    const inp = pyParse(text);
    if (!inp || !inp.letters) return { ok: false, empty: true };
    const syl = d.s.map(x => pyParse(x)),
      want = syl.map(x => x.letters).join('');
    if (inp.letters !== want) {
      const alt = similarMeaning(d).find(x => pyParse(x.s.join('')).letters === inp.letters && pyCheck(x, text).ok);
      return alt ? { ok: true, alt } : { ok: false };
    }
    const ch = [...d.h];
    let pos = 0,
      toneless = true,
      ok = true;
    syl.forEach((x, i) => {
      const end = pos + x.letters.length;
      let given = 0;
      for (let k = pos; k < end; k++) if (inp.tones[k]) given = inp.tones[k];
      if (given) toneless = false;
      const t = tone(d.s[i]),
        g = given || 5,
        c = syl.length === ch.length ? ch[i] : '';
      const fine = g === t || t === 5 || (c === '一' && [1, 2, 4].includes(g)) || (c === '不' && [2, 4].includes(g));
      if (!fine) ok = false;
      pos = end;
    });
    return { ok, toneless: toneless && !ok };
  }
  const similarMeaning = d => {
    const m = M1(d).toLowerCase();
    return DATA.filter(x => x.id !== d.id && M1(x).toLowerCase() === m);
  };

  /* ---- what to ask next ---- */
  const has = (e, k) => !!e && !!e[k] && e[k][4] > 0;
  let skillW = { m: 0, f: 0, s: 0 }; /* weakest skill overall gets a nudge */
  function pickType(d) {
    const e = mem[d.id],
      t = now();
    if (!e) return 'm';
    if (e.L === 1) {
      if (!e.f) return 'f';
      if (!e.s) return 's';
    }
    const r = se => (se ? Rt((t - se[2]) / 1440, se[1]) : 0),
      c = [['m', r(e.m)]];
    if (has(e, 'm') || e.L) {
      c.push(['f', r(e.f)]);
      c.push(['s', r(e.s)]);
    }
    const k = c.map(([k, v]) => [k, v - skillW[k] + Math.random() * 0.12]).sort((a, b) => a[1] - b[1])[0][0];
    const x = Math.random();
    if (k === 'f' && has(e, 'f') && x < 0.2) return 'p'; /* recall from memory, not from options */
    if (k === 'm' && has(e, 'm') && d.l >= 3 && clozeOK(d) && x < 0.2) return 't';
    if (k === 'f' && has(e, 'f') && clozeOK(d) && x < 0.5) return 'c';
    if (k === 's' && has(e, 's') && ttsReady() && Math.random() < 0.4) return 'l';
    return k;
  }
  function dr(g = goal) {
    if (g && g.t === 'exam' && g.date) {
      const dl = daysTo(g.date);
      if (dl >= 0 && dl <= 30) return 0.9 + 0.05 * (1 - dl / 30);
    }
    return 0.9;
  }
  const rNow = (e, t) => (e && e.w ? Rt((t - e.w[2]) / 1440, e.w[1]) : 0);
  /* words in curriculum order that haven't been seen yet; ones whose characters you already know come a little earlier,
   and two look-alikes (shared character or same syllables) are never introduced together */
  function pickNew(n, src) {
    if (n <= 0) return [];
    const cand = [];
    for (const d of src) {
      if (!mem[d.id]) cand.push(d);
      if (cand.length >= 60) break;
    }
    const sc = cand
        .map((d, i) => [i - 14 * knownShare(d) + 12 * wdiff(d), d])
        .sort((a, b) => a[0] - b[0])
        .map(p => p[1]),
      out = [],
      chars = new Set(),
      pks = new Set(); /* common, familiar-looking words a little earlier */
    for (const d of sc) {
      if (out.length >= n) break;
      if ([...d.h].some(c => chars.has(c)) || pks.has(d.pk)) continue;
      out.push(d);
      [...d.h].forEach(c => chars.add(c));
      pks.add(d.pk);
    }
    for (const d of sc) {
      if (out.length >= n) break;
      if (!out.includes(d)) out.push(d);
    }
    return out;
  }
  const tsort = a => a.slice().sort((x, y) => x.l - y.l || x.n - y.n);
  /* Cards: due words first (lowest recall chance), then up to half a round of new ones, then the rest by weakness */
  function cardDeck(pool, n) {
    const t = now(),
      r = dr(),
      due = [],
      rest = [];
    for (const d of pool) {
      const e = mem[d.id];
      if (!e) continue;
      const R = rNow(e, t);
      if (R < r) due.push([R, d]);
      else rest.push([R, d]);
    }
    due.sort((a, b) => a[0] - b[0]);
    rest.sort((a, b) => a[0] - b[0]);
    const out = due.slice(0, n).map(p => p[1]);
    if (out.length < n) out.push(...pickNew(Math.min(n - out.length, Math.max(4, Math.round(n / 2))), tsort(pool)));
    for (const p of rest) {
      if (out.length >= n) break;
      out.push(p[1]);
    }
    return spread(out.slice(0, n));
  }
  /* which words go in a round is the model's choice; the order is random (interleaving), and two look-alikes
   (a shared character, the same syllables, or a known mix-up) are never shown one after the other */
  const alike = (a, b) =>
    !!a && !!b && ([...a.h].some(c => b.h.includes(c)) || a.pk === b.pk || confs().has(pairKey(a.id, b.id)));
  function spread(words) {
    const a = shuf(words);
    for (let i = 1; i < a.length; i++)
      if (alike(a[i], a[i - 1])) {
        const j = a.findIndex((x, k) => k > i && !alike(x, a[i - 1]) && !alike(x, a[i + 1]));
        if (j > 0) [a[i], a[j]] = [a[j], a[i]];
      }
    return a;
  }
  /* Quiz round inside the chosen level/unit; type null = the app chooses per word */
  function quizRound(pool, n, type) {
    const t = now(),
      r = dr(),
      sc = [];
    const src = type === 'c' || type === 't' ? pool.filter(clozeOK) : pool;
    for (const d of src) {
      const e = mem[d.id];
      if (!e) continue;
      const R = rNow(e, t);
      sc.push([R < r ? R : e.L === 1 ? 0.95 : 1 + R, d]);
    }
    sc.sort((a, b) => a[0] - b[0]);
    let words = sc.slice(0, n).map(p => p[1]);
    const fresh = pickNew(Math.max(type ? 0 : 3, n - words.length), tsort(src));
    if (!type && words.length > n - 3 && fresh.length)
      words = words.slice(0, Math.max(0, n - Math.min(3, fresh.length)));
    words = words.concat(fresh).slice(0, n);
    return shuf(words).map(d => ({ k: 'q', d, q: type || pickType(d) }));
  }
  /* Exam simulation: a uniform sample of the cumulative vocabulary up to the level, mixed question types */
  function exam(lv, n) {
    const src = DATA.filter(d => d.l <= lv),
      out = [];
    const seen = new Set();
    while (out.length < n && seen.size < src.length) {
      const d = src[(Math.random() * src.length) | 0];
      if (seen.has(d.id)) continue;
      seen.add(d.id);
      const x = Math.random();
      let q = x < 0.3 ? 'm' : x < 0.55 ? 'f' : x < 0.75 ? 's' : 'c';
      if (q === 'c' && !clozeOK(d)) q = 'f';
      if (q === 's' && ttsReady() && Math.random() < 0.4) q = 'l';
      out.push({ k: 'q', d, q });
    }
    return out;
  }

  /* ---- HSK simulation (v1.17, Josh: a mock exam corrected automatically at the end, with advice) ----
   Built like the HSK: 听力 listening (words heard, when the phone can speak), 阅读 reading (meanings, sentence gaps,
   sentence translations from HSK 3) and 书写 writing (from HSK 3: pick the hanzi for a meaning, type the pinyin from
   memory). Questions per level and part below; 70 % of the words come from the level itself, 30 % from the levels
   under it (the exam builds on them). Each part is scored out of 100, like the HSK; passing = 60 % of the total
   (120 of 200 for HSK 1–2, 180 of 300 from HSK 3). Seconds per question by type give the time limit. */
  const MOCK = {
    1: { l: 10, m: 6, c: 4 },
    2: { l: 10, m: 6, c: 4 },
    3: { l: 12, m: 4, c: 6, t: 4, f: 4, p: 4 },
    4: { l: 12, m: 4, c: 6, t: 4, f: 4, p: 4 },
    5: { l: 15, m: 2, c: 7, t: 6, f: 3, p: 5 },
    6: { l: 15, m: 2, c: 7, t: 6, f: 3, p: 5 },
    7: { l: 15, c: 7, t: 8, f: 3, p: 5 },
  };
  const MOCK_SEC = { l: 25, m: 30, c: 60, t: 75, f: 30, p: 45 };
  const MOCK_PART = { l: 'listen', m: 'read', c: 'read', t: 'read', f: 'write', p: 'write' };
  function mockExam(L) {
    const P = MOCK[Math.min(L, 7)],
      own = shuf(DATA.filter(d => d.l === L)),
      low = shuf(DATA.filter(d => d.l < L)),
      used = new Set();
    const take = ok => {
      const first = Math.random() < 0.7 || !low.length ? own : low;
      for (const src of [first, first === own ? low : own]) {
        const d = src.find(x => !used.has(x.id) && ok(x));
        if (d) {
          used.add(d.id);
          return d;
        }
      }
      return null;
    };
    const fit = {
      l: () => true,
      m: () => true,
      c: clozeOK,
      t: clozeOK,
      f: () => true,
      p: d => [...d.h].length <= 3,
    };
    const parts = [];
    for (const part of ['listen', 'read', 'write']) {
      if (part === 'listen' && !ttsReady()) continue;
      const items = [];
      for (const q of ['l', 'm', 'c', 't', 'f', 'p'])
        if (MOCK_PART[q] === part)
          for (let i = 0; i < (P[q] || 0); i++) {
            const d = take(fit[q]);
            if (d) items.push({ k: 'q', d, q, part });
          }
      if (items.length) parts.push({ k: part, n: items.length, items });
    }
    const items = parts.flatMap(x => x.items),
      sec = items.reduce((a, it) => a + MOCK_SEC[it.q], 0);
    return { L, parts: parts.map(({ k, n }) => ({ k, n })), items, sec, skipped: !ttsReady() };
  }
  /* the result: each part out of 100, the total, the pass mark (60 % of the parts taken) */
  function mockScore(m) {
    const parts = m.parts.map(p => {
      const its = m.items.filter(it => it.part === p.k),
        right = its.filter(it => it.ok).length;
      return { k: p.k, n: its.length, right, score: Math.round((right / Math.max(1, its.length)) * 100) };
    });
    const total = parts.reduce((a, p) => a + p.score, 0),
      max = parts.length * 100;
    return { parts, total, max, need: Math.round(max * 0.6), pass: total >= max * 0.6 };
  }
  let mocks = ls.get('xc_mock', []);
  if (!Array.isArray(mocks)) mocks = [];
  /* history: [time (minutes), level, total, max, [part scores in listen/read/write order, null = not taken], seconds used] */
  function mockSave(m, r, used) {
    const by = k => {
      const p = r.parts.find(x => x.k === k);
      return p ? p.score : null;
    };
    mocks = mocks
      .concat([[now(), m.L, r.total, r.max, ['listen', 'read', 'write'].map(by), Math.round(used)]])
      .slice(-50);
    ls.set('xc_mock', mocks);
  }

  /* ---- current level and the placement test ----
   The placement test is 50 quick questions that adapt to the answers. Ability θ (0–7, "knows the words of HSK levels
   up to θ") has a probability over a grid; each answer updates it with an item-response model:
     P(knows a level-l word | θ) = 1 / (1 + e^(−2.4·(θ − b))),  b = l − 0.5 + type offset
   A learner who knows the word answers right 95 % of the time; one who doesn't presses "Don't know" or guesses one of
   four options (25 % right). The next question aims at the current estimate. Words come from a bank of words that
   bring characters new at their level (so they can't be worked out from easier words); HSK 5–6 only get the hard
   question types (recall with look-alike options, tones, sentence gaps). A level counts as mastered when θ is at
   least that level with 80 % certainty (90 % for HSK 5 and 6, which also need at least 5 questions of that level,
   70 % right), and every level below it is mastered too. Strong learners get HSK 5 and 6 questions in turn. */
  let lvInfo = ls.get('xc_lvl', null);
  if (!lvInfo || typeof lvInfo !== 'object' || !(lvInfo.lv >= 1 && lvInfo.lv <= 9)) lvInfo = null;
  /* realm (cultivation level): 0 凡人 not tested yet · 1–6 studying HSK 1–6 · 7 飞升, 8 真仙, 9 玄仙 studying the HSK 7,
   8, 9 tiers · 10 大罗 everything mastered. Realms 8–10 and the HSK 7–9 words exist only once the gate (仙门) is open:
   it opens when 飞升 is reached by a breakthrough (before v1.13 飞升 could also come from the placement test; such a
   飞升 opens the gate with a make-up tribulation, 补劫). The realm changes only through tests: the placement test (the
   way in, once) or a breakthrough (突破, one realm at a time). */
  /* a level picked by hand in v1.9 is no test: the realm stays 凡人 until a test, but the plan keeps starting at that level */
  const realm = () =>
    !lvInfo ? 0 : Number.isInteger(lvInfo.r) ? lvInfo.r : lvInfo.src === 'manual' ? 0 : lvInfo.m === 6 ? 7 : lvInfo.lv;
  const gateOpen = () => !!(lvInfo && lvInfo.gate);
  const topLevel = () => LEVELS[LEVELS.length - 1];
  /* the HSK level a realm studies: realm r studies level r; 大罗 (and a 飞升 without the gate) has nothing left */
  const realmLevel = r => Math.max(1, Math.min(topLevel(), r));
  const isFinal = r => r >= 10 || (r >= 7 && !gateOpen()) || r > topLevel();
  const baseLevel = () => {
    const r = realm();
    return r < 1 ? (lvInfo && lvInfo.src === 'manual' ? lvInfo.lv : 1) : realmLevel(r);
  };
  function curLevel() {
    const top = topLevel();
    for (let l = baseLevel(); l <= top; l++) if (BY[l].some(d => !mem[d.id])) return l;
    return top;
  }
  /* history entries: [realm, time, how ('test' recognised by the placement test, 'bt' broken through), quality 1–4] */
  function setRealm(r, src, extra) {
    const e = [r, now(), src];
    if (extra && extra.grade) e.push(extra.grade);
    const hist = ((lvInfo && lvInfo.hist) || []).concat([e]).slice(-30);
    const x = Object.assign({}, extra || {});
    delete x.grade;
    lvInfo = Object.assign({}, lvInfo || {}, x, { r, lv: Math.max(1, Math.min(9, r)), src, at: now(), hist });
    ls.set('xc_lvl', lvInfo);
  }
  const okHist = h =>
    Array.isArray(h) &&
    h.length >= 2 &&
    h.length <= 4 &&
    Number.isInteger(h[0]) &&
    h[0] >= 0 &&
    h[0] <= 10 &&
    Number.isFinite(h[1]) &&
    (h.length < 3 || ['test', 'bt'].includes(h[2])) &&
    (h.length < 4 || [1, 2, 3, 4].includes(h[3]));
  function restoreLevel(o) {
    if (o && o.lv >= 1 && o.lv <= 9 && ['test', 'manual', 'bt'].includes(o.src)) {
      const num = x => (Number.isFinite(x) ? Math.round(x) : undefined);
      lvInfo = {
        lv: o.lv,
        src: o.src,
        at: Number.isFinite(o.at) ? o.at : now(),
        r: Number.isInteger(o.r) && o.r >= 0 && o.r <= 10 ? o.r : undefined,
        hist: Array.isArray(o.hist) ? o.hist.filter(okHist).slice(-30) : undefined,
        m: Number.isInteger(o.m) && o.m >= 0 && o.m <= 6 ? o.m : undefined,
        per: Array.isArray(o.per) && o.per.length === 6 && o.per.every(Number.isFinite) ? o.per : undefined,
        th: Array.isArray(o.th) && o.th.length === 2 && o.th.every(Number.isFinite) && o.th[1] > 0 ? o.th : undefined,
        pt: Array.isArray(o.pt) ? o.pt.filter(Number.isFinite).slice(-5) : undefined,
        gate: num(o.gate),
        gs: o.gs ? 1 : undefined,
        stab: num(o.stab),
      };
      if (lvInfo.gate) lvInfo.gs = 1; /* restored on another phone: no ceremony, a short welcome instead */
      ls.set('xc_lvl', lvInfo);
    }
  }
  /* 飞升 reached by a breakthrough before v1.13: the gate opens (with its ceremony) */
  if (lvInfo && realm() === 7 && lvInfo.src === 'bt' && !lvInfo.gate) {
    lvInfo.gate = now();
    ls.set('xc_lvl', lvInfo);
  }
  function gateSeen() {
    if (lvInfo) {
      lvInfo.gs = 1;
      ls.set('xc_lvl', lvInfo);
    }
  }
  const PT = {
    N: 50,
    K: 2.4,
    G: 0.25,
    SLIP: 0.04,
    IDK: 0.6,
    DQ: { m: -0.3, f: 0, s: 0.1, c: 0.2 },
    TYPES: { 1: 'mfs', 2: 'mfs', 3: 'mfsc', 4: 'mfsc', 5: 'fsc', 6: 'fsc' },
  };
  const GRID = Array.from({ length: 71 }, (_, i) => i / 10);
  let PB = null;
  const PLV = [1, 2, 3, 4, 5, 6]; /* the placement test covers HSK 1–6 */
  function placementBank() {
    if (PB) return PB;
    PB = {};
    const seen = new Set();
    for (const l of PLV) {
      PB[l] = BY[l].filter(d => {
        const c = [...d.h];
        return (
          c.length <= 4 && (l < 3 || c.length >= 2) && (l === 1 || c.some(x => !seen.has(x))) && d.pm && clozeOK(d)
        );
      });
      BY[l].forEach(d => {
        for (const c of d.h) seen.add(c);
      });
    }
    return PB;
  }
  const pKnow = (th, b) => 1 / (1 + Math.exp(-PT.K * (th - b)));
  const itemB = (l, q, d) => l - 0.5 + PT.DQ[q] + (l >= 5 ? 0.15 : 0) + (d ? wdiff(d) * 0.8 : 0);
  /* idk = how often this learner presses "Don't know" instead of guessing, estimated from their own answers, so a
   learner who guesses everything doesn't get credit for lucky guesses */
  function likelihood(r, pk, idk) {
    const nk = 1 - pk;
    return r === 'ok'
      ? pk * (1 - PT.SLIP) + nk * (1 - idk) * PT.G
      : r === 'idk'
        ? pk * 0.01 + nk * idk
        : pk * (PT.SLIP - 0.01) + nk * (1 - idk) * (1 - PT.G);
  }
  function posterior(st) {
    const n = r => st.items.filter(x => x.r === r).length,
      a = n('idk') * (1 - PT.G),
      idk = cl((a + PT.IDK * 2) / (a + n('ng') + 2), 0.03, 0.95);
    let post = GRID.map(t => -t / 3.5);
    for (const it of st.items) {
      const b = itemB(it.l, it.q, it.d);
      post = post.map((p, i) => p + Math.log(likelihood(it.r, pKnow(GRID[i], b), idk)));
    }
    const mx = Math.max(...post);
    post = post.map(p => Math.exp(p - mx));
    const s = post.reduce((x, y) => x + y, 0);
    return post.map(p => p / s);
  }
  function ptStats(st) {
    const post = (st.post = posterior(st));
    let m = 0,
      v = 0;
    GRID.forEach((t, i) => (m += t * post[i]));
    GRID.forEach((t, i) => (v += (t - m) * (t - m) * post[i]));
    return { mean: m, sd: Math.sqrt(v) };
  }
  function ptStart() {
    placementBank();
    return { post: null, items: [], used: new Set(), chars: new Set() };
  }
  /* the next question: three warm-ups (HSK 1, 2, 3), then aimed at the estimate, with a little spread */
  function ptNext(st) {
    const n = st.items.length;
    if (n >= PT.N) return null;
    const { mean, sd } = ptStats(st);
    let l = n < 3 ? n + 1 : Math.round(mean + 0.5 + (Math.random() - 0.5) * Math.min(1.2, sd));
    l = cl(l, 1, 6);
    if (n >= 3 && mean >= 4.3) {
      const c5 = st.items.filter(x => x.l === 5).length,
        c6 = st.items.filter(x => x.l === 6).length;
      l = c5 === c6 ? (mean >= 5.5 ? 6 : 5) : c5 < c6 ? 5 : 6;
    } /* strong learners: test HSK 5 and 6 evenly */
    const types = PT.TYPES[l],
      cnt = q => st.items.filter(x => x.q === q).length;
    const q = [...types].sort((a, b) => cnt(a) - cnt(b) + (Math.random() - 0.5) * 0.5)[0];
    const pool = PB[l].filter(d => !st.used.has(d.id) && !(q === 'c' && !clozeOK(d)));
    const fresh = pool.filter(
      d => ![...d.h].some(c => st.chars.has(c)),
    ); /* no shared characters with earlier questions (no hints) */
    const src = fresh.length ? fresh : pool,
      d = src[(Math.random() * src.length) | 0];
    st.used.add(d.id);
    [...d.h].forEach(c => st.chars.add(c));
    const it = { d, l, q };
    Object.assign(it, question(d, q, l >= 4 ? 0.85 : 0.5));
    return it;
  }
  function ptAnswer(st, it, r) {
    it.r = r;
    st.items.push(it);
  }
  function ptResult(st) {
    const { mean, sd } = ptStats(st),
      ge = l => GRID.reduce((a, t, i) => a + (t >= l - 1e-9 ? st.post[i] : 0), 0);
    const pass = l => {
      if (ge(l) < (l >= 5 ? 0.9 : 0.8)) return false;
      if (l < 5) return true;
      const it = st.items.filter(x => x.l === l),
        ok = it.filter(x => x.r === 'ok').length;
      return it.length >= 5 && ok / it.length >= 0.7;
    };
    let m = 0;
    for (const l of PLV) {
      if (pass(l)) m = l;
      else break;
    }
    const per = PLV.map(l => Math.round(GRID.reduce((a, t, i) => a + st.post[i] * pKnow(t, l - 0.5), 0) * 100));
    const right = st.items.filter(x => x.r === 'ok').length,
      idk = st.items.filter(x => x.r === 'idk').length;
    return { m, lv: Math.min(6, m + 1), mean, sd, per, right, idk, n: st.items.length };
  }

  /* ---- realms, stages, breakthrough, weekly test ----
   Stage inside the realm = share of that HSK level's words that are solid: 初期 <25 %, 中期 25–50 %, 后期 50–80 %,
   圆满 ≥80 %. At 圆满 the breakthrough opens: 20 questions on words of the level (hard types from HSK 4), passed with
   75 % right (80 % for HSK 5 and 6). One test a week — placement or breakthrough — counted from the last one. */
  const WEEK = 7 * 1440;
  let tests = ls.get('xc_tests', []);
  if (!Array.isArray(tests)) tests = [];
  if (!tests.length && lvInfo && lvInfo.src === 'test' && Number.isFinite(lvInfo.at))
    tests = [lvInfo.at]; /* a placement test taken in v1.9 counts */
  function restoreExtra(o) {
    if (!o) return;
    if (Array.isArray(o.tests)) {
      tests = o.tests.filter(Number.isFinite).map(Math.round).slice(-30);
      ls.set('xc_tests', tests);
    }
    if (Array.isArray(o.rest)) setRest(o.rest);
    if (Array.isArray(o.days)) {
      days0 = o.days.filter(Number.isInteger).slice(-730);
      ls.set('xc_days', days0);
    }
    if (Array.isArray(o.mock)) {
      mocks = o.mock
        .filter(x => Array.isArray(x) && x.length >= 5 && Number.isFinite(x[0]) && x[1] >= 1 && x[1] <= 9)
        .slice(-50);
      ls.set('xc_mock', mocks);
    }
  }
  const nextTestAt = () => (tests.length ? Math.max(...tests) + WEEK : 0);
  const canTest = () => now() >= nextTestAt();
  function noteTest() {
    tests = tests.concat(now()).slice(-30);
    ls.set('xc_tests', tests);
  }
  /* stage share = (solid words + ½ × the test's estimate for the words not solid yet) ÷ the level's words */
  function credit(L) {
    const W = BY[L],
      P = testP(L),
      c = new Float32Array(W.length);
    W.forEach((d, j) => {
      const e = mem[d.id];
      if (solid(e)) {
        c[j] = 1;
        return;
      }
      if (!P) return;
      const ok = e ? lastOk(e) : null;
      if (ok === false) return;
      c[j] = 0.5 * (ok ? Math.max(P[j], 0.9) : P[j]);
    });
    return c;
  }
  function stage(r = realm()) {
    if (r < 1) return null;
    const L = realmLevel(r),
      W = BY[L];
    if (isFinal(r))
      return { i: 3, share: 1, solid: W.length, test: 0, testShare: 0, total: W.length, need: 0, final: true };
    const c = credit(L);
    let n = 0,
      sum = 0,
      est = 0;
    for (let j = 0; j < c.length; j++) {
      sum += c[j];
      if (c[j] === 1) n++;
      else est += c[j] * 2;
    }
    const share = sum / W.length,
      need = Math.max(0, Math.ceil(W.length * 0.8 - sum));
    return {
      i: share >= 0.8 ? 3 : share >= 0.5 ? 2 : share >= 0.25 ? 1 : 0,
      share,
      solid: n,
      test: Math.round(est),
      testShare: (sum - n) / W.length,
      total: W.length,
      need,
    };
  }

  /* ---- a stable realm (境界稳固) ----
   A realm rests on the level below it (the one its breakthrough proved). If that level fades — spaced answers on its
   words in the last 30 days under 70 % right (at least 15 answers), or the model's recall now of its studied words under
   60 % (at least 20 words) — the realm is unstable (境界不稳): the breakthrough waits until a stabilising trial
   (试炼稳固: 15 of the faded words, 80 % right) is passed. The realm itself never drops. */
  function stability(r = realm()) {
    if (r < 2) return { ok: true };
    const P = realmLevel(r - 1),
      t = now(),
      t0 = t - 30 * 1440,
      pre = P + ':';
    if (lvInfo && lvInfo.stab && t - lvInfo.stab < 30 * 1440) {
      /* stabilised lately: stays stable unless it fades again after the trial */
      return stabCheck(P, pre, Math.max(t0, lvInfo.stab), t, true);
    }
    return stabCheck(P, pre, t0, t, false);
  }
  function stabCheck(P, pre, t0, t, after) {
    const L = allLog(),
      seen = new Set();
    let n = 0,
      c = 0;
    for (let i = L.length - 1; i >= 0; i--) {
      const e = L[i];
      if (e[0] < t0 || (after && e[0] === t0)) break; /* after a trial: only answers given after it */
      if (!e[1].startsWith(pre) || e[6] & 48 || !QUIZ.has(e[2])) continue;
      const k = e[1] + '@' + dayOf(e[0]),
        m = mem[e[1]];
      if (seen.has(k) || !m || dayOf(m.i) >= dayOf(e[0])) continue; /* first answer of a day on a word met earlier */
      seen.add(k);
      n++;
      if (e[3] > 1) c++;
    }
    let rs = 0,
      rn = 0;
    for (const d of BY[P]) {
      const e = mem[d.id];
      if (!e) continue;
      rs += rNow(e, t);
      rn++;
    }
    const acc = n ? c / n : null,
      rec = rn ? rs / rn : null;
    const badAcc = n >= 15 && acc < 0.7,
      badRec = !after && rn >= 20 && rec < 0.6;
    return { ok: !(badAcc || badRec), P, n, acc, rn, rec, why: badAcc ? 'acc' : badRec ? 'rec' : null };
  }
  function stabWords(n = 15) {
    const s = stability();
    if (s.ok) return [];
    const t = now();
    return BY[s.P]
      .filter(d => mem[d.id])
      .map(d => [rNow(mem[d.id], t), d])
      .sort((a, b) => a[0] - b[0])
      .slice(0, n)
      .map(p => p[1]);
  }
  function stabDone(right, total) {
    if (!total || right / total < 0.8) return false;
    lvInfo = Object.assign({}, lvInfo || {}, { stab: now() });
    ls.set('xc_lvl', lvInfo);
    return true;
  }

  /* ---- the tribulation (雷劫): a breakthrough in strikes ----
   At 圆满 the breakthrough opens. It is a series of strikes, each a skill on the realm's own words, with no feedback:
     识 shí meaning · 忆 yì the pinyin typed from memory · 听 tīng listening (left out if the phone has no voice) ·
     读 dú the word that fits a sentence · 速 sù meanings against the clock (6 s per question for HSK 1–3, 5 s for 4–6,
     4 s for 7–9) · 译 yì the translation of a sentence (HSK 7–9 only).
   It is passed when every strike has at least 70 % right AND the whole has at least 75 % (80 % from HSK 5, 85 % for
   HSK 7–9) — luck in one strike can't carry a weak skill. The margin decides the foundation's quality (道基):
   完美 perfect = not one wrong answer in all strikes · 上品 high ≥ the cut + 15 points (at most 97 %) ·
   中品 middle ≥ the cut + 8 (at most 93 %) · 下品 low otherwise. Only a breakthrough gives a quality; a realm the
   placement test recognised (认定) has none. One test a week, as before. */
  const STRIKES = [
    { k: 'shi', hz: '识', py: 'shí', q: 'm', n: 5 },
    { k: 'yi', hz: '忆', py: 'yì', q: 'p', n: 5 },
    { k: 'ting', hz: '听', py: 'tīng', q: 'l', n: 5, tts: true },
    { k: 'du', hz: '读', py: 'dú', q: 'c', n: 5 },
    { k: 'su', hz: '速', py: 'sù', q: 'm', n: 8, timed: true },
    { k: 'fan', hz: '译', py: 'yì', q: 't', n: 5, band: true },
  ];
  const cutOf = L => (L >= 7 ? 0.85 : L >= 5 ? 0.8 : 0.75);
  const limitOf = L => (L <= 3 ? 6 : L <= 6 ? 5 : 4);
  const GRADES = ['', '下品', '中品', '上品', '完美'];
  const btReady = () => {
    const r = realm();
    return r >= 1 && !isFinal(r) && stage(r).i === 3 && stability(r).ok;
  };
  const btOpen = () => btReady() || makeupOpen();
  /* 飞升 from a placement test before v1.13: a make-up tribulation on HSK 6 opens the gate */
  const makeupOpen = () => realm() === 7 && !gateOpen() && LEVELS.includes(6);
  function btStart() {
    placementBank();
    const r = realm(),
      makeup = makeupOpen(),
      L = makeup ? 6 : realmLevel(r),
      hard = L >= 4 ? 0.85 : 0.6,
      base = (L <= 6 && PB[L] && PB[L].length >= 40 ? PB[L] : BY[L]).filter(clozeOK);
    const pool = shuf(base.length >= 40 ? base : BY[L]),
      used = new Set(),
      items = [],
      strikes = [];
    const take = ok => {
      const d = pool.find(x => !used.has(x.id) && ok(x)) || shuf(BY[L]).find(x => !used.has(x.id) && ok(x));
      if (d) used.add(d.id);
      return d;
    };
    for (const S of STRIKES) {
      if (S.band && L < 7) continue;
      if (S.tts && !ttsReady()) {
        strikes.push({ k: S.k, hz: S.hz, py: S.py, n: 0, skipped: true });
        continue;
      }
      let n = 0;
      for (let i = 0; i < S.n; i++) {
        const d = take(x => (S.q === 'c' || S.q === 't' ? clozeOK(x) : true));
        if (!d) break;
        const it = { d, l: L, q: S.q, strike: S.k };
        if (S.timed) it.limit = limitOf(L);
        Object.assign(it, question(d, S.q, hard));
        items.push(it);
        n++;
      }
      strikes.push({ k: S.k, hz: S.hz, py: S.py, n, timed: !!S.timed });
    }
    return { r, L, makeup, items, strikes, i: 0, right: 0 };
  }
  function btFinish(st) {
    const cut = cutOf(st.L),
      res = st.strikes.map(S => {
        if (S.skipped) return Object.assign({}, S, { right: 0, pass: true });
        const its = st.items.filter(x => x.strike === S.k),
          right = its.filter(x => x.r === 'ok').length;
        return Object.assign({}, S, { right, pass: right >= Math.ceil(its.length * 0.7) });
      });
    const n = st.items.length,
      right = st.items.filter(x => x.r === 'ok').length,
      acc = n ? right / n : 0,
      pass = res.every(x => x.pass) && acc >= cut;
    noteTest();
    let grade = 0,
      gate = false;
    if (pass) {
      grade =
        right === n && !res.some(x => x.skipped)
          ? 4
          : acc >= Math.min(cut + 0.15, 0.97)
            ? 3
            : acc >= Math.min(cut + 0.08, 0.93)
              ? 2
              : 1;
      const th = testTh(),
        x = { grade };
      /* a passed breakthrough proves the level: a placement test's ability estimate moves up to at least that level
         (without a placement test there is no estimate, and the next realm starts from its solid words alone) */
      if (th && st.L <= 6) x.th = [r2(Math.max(th[0], st.L)), r2(Math.min(th[1], 0.6))];
      if (st.makeup) {
        x.gate = now();
        setRealm(7, 'bt', x);
        gate = true;
      } else {
        if (st.r + 1 === 7) x.gate = now();
        setRealm(st.r + 1, 'bt', x);
        gate = st.r + 1 === 7;
      }
    }
    return {
      pass,
      need: cut,
      acc,
      right,
      n,
      grade,
      gate,
      strikes: res,
      r: realm(),
      makeup: st.makeup,
      weak: st.items.filter(x => x.r !== 'ok').map(x => x.d),
    };
  }
  /* the quality of each realm reached by a breakthrough, from the history: {realm: 1–4} (best kept) */
  function grades() {
    const g = {};
    for (const h of (lvInfo && lvInfo.hist) || []) if (h[2] === 'bt' && h[3]) g[h[0]] = Math.max(g[h[0]] || 0, h[3]);
    return g;
  }

  /* ---- the placement test is the way in ----
   The first placement test sets the starting realm (at most 渡劫: 飞升 and above are only reached by breaking
   through). One retake is allowed within 14 days of the first test, in case the first went wrong; it replaces the
   result. After that the realm only moves by breakthroughs. Tests from before v1.13 count as the first test. */
  const ptTimes = () => {
    if (!lvInfo) return [];
    if (Array.isArray(lvInfo.pt)) return lvInfo.pt;
    return lvInfo.src === 'test' || (lvInfo.hist || []).some(h => h[2] === 'test') ? [lvInfo.at] : [];
  };
  function ptOpen() {
    const T = ptTimes();
    if (!T.length) return realm() === 0 ? (canTest() ? 'first' : 'wait') : null;
    if (T.length === 1 && now() - T[0] <= 14 * 1440 && lvInfo && lvInfo.src === 'test') return 'retake';
    return null;
  }
  const ptRetakeUntil = () => {
    const T = ptTimes();
    return T.length === 1 ? T[0] + 14 * 1440 : 0;
  };
  function placementDone(res) {
    const T = ptTimes();
    noteTest();
    setRealm(Math.min(6, res.m + 1), 'test', {
      m: res.m,
      per: res.per,
      th: [r2(res.mean), r2(Math.max(0.15, res.sd))],
      pt: T.concat(now()).slice(-5),
    });
  }

  /* ---- what the placement test says about the realm's words ----
   The test ends with an ability estimate (mean and spread of θ). With the same item model it gives every word of a
   level a chance that the learner already knows it: p = Σ P(θ)·P(knows | θ, the word's difficulty). Realm progress
   counts that knowledge at half weight until practice proves the word solid (then it counts fully); a word answered
   wrong since loses its test credit. Tests from v1.9–v1.11 kept only the six level shares, so θ is fitted to those. */
  function testTh() {
    if (!lvInfo) return null;
    if (lvInfo.th) return lvInfo.th;
    const per = lvInfo.per;
    if (!per || lvInfo.src === 'manual') return null;
    let best = 0,
      err = 1e9;
    for (const t of GRID) {
      let e = 0;
      PLV.forEach((l, i) => {
        const d = pKnow(t, l - 0.5) - per[i] / 100;
        e += d * d;
      });
      if (e < err) {
        err = e;
        best = t;
      }
    }
    return [best, 0.5];
  }
  let TP = null;
  function testP(L) {
    const th = testTh();
    if (!th || L > 6) return null; /* the test says nothing about HSK 7–9 */
    const key = L + ':' + th.join(',');
    if (TP && TP.key === key) return TP.p;
    const [m, sd] = th,
      w = GRID.map(t => Math.exp(-0.5 * ((t - m) / sd) ** 2)),
      ws = w.reduce((a, b) => a + b, 0);
    const p = new Float32Array(BY[L].length);
    BY[L].forEach((d, j) => {
      const b = itemB(L, 'f', d);
      let s = 0;
      GRID.forEach((t, i) => {
        if (w[i] > 1e-6) s += w[i] * pKnow(t, b);
      });
      p[j] = s / ws;
    });
    TP = { key, p };
    return p;
  }
  /* the most recent skill answer of a word: true right, false wrong, null none */
  function lastOk(e) {
    let t = -1,
      g = 0;
    for (const k of ['m', 'f', 's']) {
      const se = e[k];
      if (se && se[2] > t) {
        t = se[2];
        g = se[3];
      }
    }
    return t < 0 ? null : g > 1;
  }

  /* ---- cultivation days (streak), meditation days, daily challenge ---- */
  let rest = ls.get('xc_rest', []);
  if (!Array.isArray(rest)) rest = [];
  rest = rest.filter(x => Number.isInteger(x) && x >= 0 && x <= 6).slice(0, 2);
  const weekday = day => new Date((day * 1440 + TZ) * 6e4 + EPOCH).getDay();
  const isRest = day => rest.includes(weekday(day));
  function setRest(a) {
    rest = a.filter(x => Number.isInteger(x) && x >= 0 && x <= 6).slice(0, 2);
    ls.set('xc_rest', rest);
  }
  /* days with practice: from the answer log, plus the days a restored backup code brought (the log isn't in the code) */
  let days0 = ls.get('xc_days', []);
  if (!Array.isArray(days0)) days0 = [];
  function studyDays() {
    const s = new Set(days0.filter(Number.isInteger));
    for (const e of allLog()) if (!(e[6] & 16)) s.add(dayOf(e[0]));
    return s;
  }
  /* consecutive days of cultivation: a day with practice counts; a chosen meditation day (闭关) and one free day off
   a week keep the run going, so one missed day never wipes it out */
  function streak() {
    const S = studyDays();
    if (!S.size) return { days: 0, today: false };
    const today = dayOf(now());
    let d = S.has(today) ? today : today - 1,
      n = 0,
      grace = -99;
    for (let k = 0; k < 3650; k++, d--) {
      if (S.has(d)) {
        n++;
        continue;
      }
      if (isRest(d)) {
        n++;
        continue;
      }
      if (grace - d >= 7 || grace === -99) {
        grace = d;
        n++;
        continue;
      }
      break;
    }
    /* free days at the very start of the run don't count */
    while (n > 0 && !S.has(d + 1) && d + 1 < today) {
      d++;
      n--;
    }
    return { days: n, today: S.has(today) };
  }
  let game = ls.get('xc_game', {});
  if (!game || typeof game !== 'object') game = {};
  /* today's challenge: the learner's weakest skill, with a target a bit above their own last-7-days level
   (number of answers ×1.15, accuracy +10 points) — hard enough to stretch, close enough to reach */
  const SKQ = { m: ['m', 'cm'], f: ['f', 'c'], s: ['s', 'l', 'cs'] };
  function challenge() {
    const today = dayOf(now());
    if (!game.chal || game.chal.day !== today) {
      const L = allLog(),
        cnt = { m: 0, f: 0, s: 0 },
        ok = { m: 0, f: 0, s: 0 },
        days = new Set();
      for (let i = L.length - 1; i >= 0; i--) {
        const e = L[i],
          d = dayOf(e[0]);
        if (d >= today) continue;
        if (today - d > 7) break;
        if (e[6] & 24) continue;
        for (const k in SKQ)
          if (SKQ[k].includes(e[2])) {
            cnt[k]++;
            if (e[3] > 1) ok[k]++;
            days.add(d);
          }
      }
      const acc = k => (cnt[k] >= 8 ? ok[k] / cnt[k] : null);
      let k = 'm';
      const cand = ['s', 'f', 'm'].filter(x => acc(x) !== null).sort((a, b) => acc(a) - acc(b));
      if (cand.length) k = cand[0];
      else if (cnt.m >= 8) k = 'f';
      const perDay = days.size ? cnt[k] / days.size : 0;
      game.chal = {
        day: today,
        k,
        n: cl(Math.round((perDay * 1.15) / 5) * 5 || 10, 10, 30),
        a: acc(k) === null ? 75 : cl(Math.round((acc(k) * 100 + 10) / 5) * 5, 70, 95),
        done: false,
      };
      ls.set('xc_game', game);
    }
    const c = game.chal,
      L = allLog();
    let n = 0,
      o = 0;
    for (let i = L.length - 1; i >= 0; i--) {
      const e = L[i];
      if (dayOf(e[0]) !== today) break;
      if (e[6] & 24) continue;
      if (SKQ[c.k].includes(e[2])) {
        n++;
        if (e[3] > 1) o++;
      }
    }
    const acc = n ? Math.round((o / n) * 100) : 0,
      done = n >= c.n && acc >= c.a;
    if (done && !c.done) {
      c.done = true;
      game.chalN = (game.chalN || 0) + 1;
      ls.set('xc_game', game);
    }
    return Object.assign({}, c, { cnt: n, acc, done: c.done || done, total: game.chalN || 0 });
  }

  /* ---- rest: the memory model's own numbers ---- */
  /* what one more right answer adds to a word's memory now vs after a night's sleep vs after 2 days (in days) */
  function restGain() {
    const e = Object.values(mem).filter(x => x.w[1] >= 1);
    if (!e.length) return null;
    const med = a => {
        a = a.slice().sort((x, y) => x - y);
        return a[a.length >> 1];
      },
      D = med(e.map(x => x.w[0])),
      S = med(e.map(x => x.w[1])),
      t0 = 1e6;
    const g = dt => step(W, [D, S, t0], 3, t0 + dt)[1] - S;
    return { now: g(10), day: g(1440), two: g(2880), S };
  }
  function gainList(words) {
    let a = 0,
      b = 0,
      n = 0;
    const t = now();
    for (const d of words) {
      const e = mem[d.id];
      if (!e || dayOf(e.w[2]) !== dayOf(t)) continue;
      n++;
      a += step(W, e.w, 3, t)[1] - e.w[1];
      b += step(W, e.w, 3, e.w[2] + 1440 * 1.5)[1] - e.w[1];
    }
    return { n, now: a, later: b };
  }
  /* days since the last practice and how much is still remembered (shown after a break) */
  function sinceLast() {
    const L = allLog();
    for (let i = L.length - 1; i >= 0; i--)
      if (!(L[i][6] & 16)) {
        const gap = dayOf(now()) - dayOf(L[i][0]);
        let rs = 0,
          rn = 0;
        const t = now();
        for (const id in mem) {
          rs += rNow(mem[id], t);
          rn++;
        }
        return { gap, recall: rn ? Math.round((rs / rn) * 100) : null };
      }
    return null;
  }

  /* ---- the five elements of the soul (五行), each 0–100 for the wheel ----
   Each one is a count against a fixed scale, so none fills up from a handful of answers (v1.12):
   土 根基 foundation = realm progress: solid words of the realm's level (+ half the placement test's estimate)
   木 修为 cultivation = memory days stored over all words (log scale; every word remembered 4 months = 100)
   水 神识 spiritual sense = words of the realm's level you'd recall right now (sum of recall chances ÷ the level's words)
   金 道心 dao heart = "I know it" claims that held up — checked at once, or by the next answer within 14 days —
                     counted from the last 90 days with 20 neutral claims (half right) added, so it takes many honest
                     claims to rise: 10 of 10 → 67, 40 of 40 → 83, 100 of 100 → 92
   火 悟性 comprehension = how fast new words become solid (median days over at least 10 words; 4 days = 100, 30 = 0) */
  const DAO_A = 20;
  function daoStat() {
    const L = allLog(),
      t0 = now() - 90 * 1440,
      open = new Map();
    let n = 0,
      c = 0;
    for (const e of L) {
      if (e[0] < t0 || e[6] & 16) continue;
      const id = e[1],
        q = e[2],
        f = e[6];
      if (f & 2 && (q === 'cm' || q === 'cs')) {
        n++;
        if (e[3] > 1) c++;
        open.delete(id);
        continue;
      }
      if (f & 2 && f & 1) {
        open.set(id, e[0]);
        continue;
      }
      if (open.has(id) && (QUIZ.has(q) || q === 'cn') && !(f & 32)) {
        const t = open.get(id);
        open.delete(id);
        if (e[0] - t <= 14 * 1440) {
          n++;
          if (e[3] > 1) c++;
        }
      }
    }
    return { n, c, score: (c + DAO_A / 2) / (n + DAO_A) };
  }
  function soul() {
    const t = now(),
      r = realm(),
      L = r < 1 ? baseLevel() : realmLevel(r),
      st = stage(r < 1 ? L : r),
      es = Object.values(mem);
    let X = 0;
    for (const e of es) X += Math.min(e.w[1], 365);
    let rs = 0;
    for (const d of BY[L]) {
      const e = mem[d.id];
      if (e) rs += rNow(e, t);
    }
    const ks = es
        .filter(e => e.k && e.i)
        .map(e => (e.k - e.i) / 1440)
        .filter(x => x >= 0)
        .sort((a, b) => a - b),
      dao = daoStat();
    const v = x => (x === null ? null : Math.round(cl(x, 0, 100)));
    return {
      L,
      root: v(st ? st.share * 100 : es.length ? 0 : null),
      cult: v((100 * Math.log(1 + X / 100)) / Math.log(1 + (DATA.length * 120) / 100)),
      cultDays: Math.round(X),
      sense: v(es.length ? (rs / BY[L].length) * 100 : null),
      senseN: Math.round(rs),
      senseOf: BY[L].length,
      dao: v(dao.n >= 5 ? dao.score * 100 : null),
      daoN: dao.n,
      daoOk: dao.c,
      insight: v(ks.length >= 10 ? (100 * (30 - ks[ks.length >> 1])) / 26 : null),
      insightDays: ks.length >= 10 ? Math.round(ks[ks.length >> 1]) : null,
      words: es.length,
    };
  }

  /* ---- guidance (指点): what to work on to move up, and when the next stage is likely ----
   Everything is read from the memory model: a word is solid at level 10+ with a passed recall (f) and tone (s)
   question, so the quickest wins are words already at level 10 that miss one of those answers. Young words need time:
   their expected days to solid come from simulating FSRS with right answers on the due dates. */
  const SOLID_S = Math.pow(121, 0.5) - 1; /* stability (days) that gives level 10 */
  function daysToSolid(e, t) {
    let D = e.w[0],
      S = e.w[1],
      d = Math.max(0, (e.w[2] + ivl(S, 0.9) * 1440 - t) / 1440),
      n = 0;
    while (S < SOLID_S && n < 30) {
      const gap = Math.max(1, ivl(S, 0.9));
      const st = step(W, [D, S, 0], 3, gap * 1440);
      D = st[0];
      S = st[1];
      if (S >= SOLID_S) break;
      d += gap;
      n++;
    }
    return Math.min(365, d);
  }
  function advice() {
    const t = now(),
      r = realm(),
      L = r < 1 ? baseLevel() : realmLevel(r),
      Wd = BY[L],
      R0 = dr(),
      out = [];
    const neu = [],
      young = [],
      needF = [],
      needS = [],
      due = [];
    for (const d of Wd) {
      const e = mem[d.id];
      if (!e) {
        neu.push(d);
        continue;
      }
      if (rNow(e, t) < R0) due.push(d);
      if (solid(e)) continue;
      if (levelOf(e) >= 10 || e.w[1] >= SOLID_S) {
        if (!okS(e.f)) needF.push(d);
        else if (!okS(e.s)) needS.push(d);
      } else young.push(e);
    }
    const pt = ptOpen();
    if (r < 1 && pt === 'first') out.push({ k: 'test' });
    const sb = stability(r);
    if (!sb.ok) out.unshift({ k: 'unstable', P: sb.P, acc: sb.acc, rec: sb.rec, why: sb.why });
    if (makeupOpen()) out.push({ k: 'makeup' });
    if (needF.length) out.push({ k: 'f', n: needF.length, words: needF.slice(0, 12), L });
    if (needS.length) out.push({ k: 's', n: needS.length, words: needS.slice(0, 12), L });
    if (due.length) out.push({ k: 'due', n: due.length, L });
    const I = insights();
    if (I.weak) out.push({ k: 'skill', q: I.weak, p: I.skills[I.weak].p });
    if (young.length) {
      const ds = young
        .slice(0, 300)
        .map(e => daysToSolid(e, t))
        .sort((a, b) => a - b);
      out.push({ k: 'young', n: young.length, days: Math.max(1, Math.round(ds[ds.length >> 1])), L });
    }
    if (neu.length) out.push({ k: 'new', n: neu.length, L });
    const pr = [...confs()].filter(p => p[1] >= 2).sort((a, b) => b[1] - a[1])[0];
    if (pr) {
      const [a, b] = pr[0].split('|');
      if (IDX.has(a) && IDX.has(b)) out.push({ k: 'conf', a: IDX.get(a), b: IDX.get(b), n: pr[1] });
    }
    const c = calib();
    if (c.n >= 8 && c.acc < 0.75) out.push({ k: 'dao', p: Math.round(c.acc * 100) });
    return { L, items: out };
  }
  /* when the next stage (and 圆满) is likely: new solid words of the level over the last 14 days */
  function forecast() {
    const r = realm(),
      L = r < 1 ? baseLevel() : realmLevel(r),
      st = stage(r < 1 ? L : r);
    if (!st || st.final) return null;
    /* progress gained by words that became solid in the last 14 days (a word the test already credited adds the rest) */
    const t = now(),
      P = testP(L);
    let n = 0;
    BY[L].forEach((d, j) => {
      const e = mem[d.id];
      if (e && e.k && t - e.k < 14 * 1440 && solid(e)) n += P ? 1 - 0.5 * P[j] : 1;
    });
    const done = st.share * st.total,
      rate = n / 14,
      T = [0.25, 0.5, 0.8],
      next = st.i < 3 ? Math.max(0, Math.ceil(st.total * T[st.i] - done)) : 0;
    return {
      rate,
      week: Math.round(rate * 7),
      next,
      need: st.need,
      dNext: rate > 0 && next ? Math.ceil(next / rate) : null,
      dFull: rate > 0 && st.need ? Math.ceil(st.need / rate) : null,
    };
  }
  /* chance to pass the tribulation now: each word is answered right with its recall chance (plus a little guessing
   on choice questions; typed pinyin has no guessing and the timed strike costs a little). Every strike needs 70 % and
   the whole needs the cut; the strikes are taken as independent: P = P(total ≥ cut) × Π P(strike ≥ 70 %). */
  function btChance() {
    const r = realm(),
      makeup = makeupOpen();
    if (r < 1 || (isFinal(r) && !makeup)) return null;
    placementBank();
    const L = makeup ? 6 : realmLevel(r),
      t = now(),
      bank = L <= 6 && PB[L] && PB[L].length >= 20 ? PB[L] : BY[L],
      hard = L >= 4 ? 0.9 : 0.95;
    let ch = 0,
      ty = 0;
    for (const d of bank) {
      const e = mem[d.id],
        R = e ? rNow(e, t) : 0;
      ch += Math.min(0.99, R * hard + (1 - R * hard) * 0.12);
      ty += Math.min(0.97, R * (e && okS(e.f) ? 0.85 : 0.6));
    }
    const pc = ch / bank.length,
      pt = ty / bank.length;
    const binomGE = (n, p, k) => {
      let s = 0;
      for (let i = k; i <= n; i++) {
        let c = 1;
        for (let j = 0; j < i; j++) c = (c * (n - j)) / (j + 1);
        s += c * Math.pow(p, i) * Math.pow(1 - p, n - i);
      }
      return s;
    };
    let prod = 1,
      mean = 0,
      vr = 0,
      N = 0;
    for (const S of STRIKES) {
      if ((S.band && L < 7) || (S.tts && !ttsReady())) continue;
      const p = S.q === 'p' ? pt : S.timed ? pc * 0.93 : pc;
      prod *= binomGE(S.n, p, Math.ceil(S.n * 0.7));
      N += S.n;
      mean += S.n * p;
      vr += S.n * p * (1 - p);
    }
    const need = Math.ceil(N * cutOf(L)),
      z = (need - 0.5 - mean) / Math.sqrt(Math.max(0.25, vr));
    const phi = x => {
      const k = 1 / (1 + 0.2316419 * Math.abs(x)),
        y =
          0.3989423 *
          Math.exp((-x * x) / 2) *
          k *
          (0.3193815 + k * (-0.3565638 + k * (1.781478 + k * (-1.821256 + k * 1.330274))));
      return x > 0 ? 1 - y : y;
    };
    return Math.round(100 * (1 - phi(z)) * prod);
  }

  /* ---- goals and the daily plan ---- */
  function validGoal(g) {
    return (
      !!g &&
      typeof g === 'object' &&
      ['level', 'exam', 'none'].includes(g.t) &&
      (g.t === 'none' || (LEVELS.includes(g.lv) && /^\d{4}-\d\d-\d\d$/.test(g.date || ''))) &&
      ['min', 'new', 'auto'].includes(g.pace) &&
      (g.pace === 'auto' || g.n > 0)
    );
  }
  function daysTo(date) {
    const [y, m, d] = date.split('-').map(Number),
      a = new Date(y, m - 1, d),
      b = new Date();
    b.setHours(0, 0, 0, 0);
    return Math.round((a - b) / 864e5);
  }
  function dayAfter(n) {
    const d = new Date();
    d.setHours(12, 0, 0, 0);
    d.setDate(d.getDate() + Math.round(n));
    return d;
  }
  const isoDay = d =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  /* seconds per review / per new word, learned from your own answering speed */
  function pace() {
    const L = allLog(),
      a = [],
      c = [];
    for (let i = L.length - 1; i >= 0 && i > L.length - 600; i--) {
      const e = L[i];
      if (QUIZ.has(e[2])) a.push(e[4] / 10);
      else if (e[2][0] === 'c') c.push(e[4] / 10);
    }
    const med = x => {
      x.sort((p, q) => p - q);
      return x[x.length >> 1];
    };
    return { rev: a.length >= 15 ? cl(med(a) + 4, 5, 30) : 10, neu: c.length >= 10 ? cl(med(c) + 24, 18, 60) : 30 };
  }
  /* days until every target word has been introduced; with a minutes-per-day budget the reviews of words already
   learned take a growing share of the time (about 0.08 reviews a day per word), so fewer new words fit later on */
  function finishDays(g, nd, remaining, load, sp) {
    if (g.pace !== 'min') return nd > 0 ? Math.ceil(remaining / nd) : null;
    const perNew = sp.neu + 2.5 * sp.rev;
    let rem = remaining,
      l = load,
      d = 0;
    while (rem > 0 && d < 1500) {
      const n = cl(Math.floor((g.n * 60 - l * sp.rev) / perNew), 0, 40);
      if (n <= 0) return null;
      rem -= n;
      l += n * 0.08;
      d++;
    }
    return rem > 0 ? null : d;
  }
  /* the fewest minutes a day that still introduce every target word in time (null if even 4 hours a day can't) */
  function minutesFor(remaining, load, sp, limit) {
    const fd = m => finishDays({ pace: 'min', n: m }, 0, remaining, load, sp);
    const ok = m => {
      const d = fd(m);
      return d !== null && d <= limit;
    };
    if (!ok(240)) return null;
    let lo = 1,
      hi = 240;
    while (lo < hi) {
      const m = (lo + hi) >> 1;
      if (ok(m)) hi = m;
      else lo = m + 1;
    }
    return lo;
  }
  function plan(g = goal) {
    const t = now(),
      today = dayOf(t),
      r = dr(g),
      sp = pace();
    let due = 0,
      load = 0,
      introT = 0;
    const pre = isRest(today + 1) ? 1440 : 0; /* before a meditation day, tomorrow's reviews are pulled into today */
    for (const id in mem) {
      const e = mem[id];
      if (rNow(e, t + pre) < r) due++;
      load += 1 / Math.max(1, ivl(e.w[1], r));
      if (e.i && !e.p && dayOf(e.i) === today) introT++;
    }
    let ansT = 0,
      secT = 0;
    const L = allLog();
    for (let i = L.length - 1; i >= 0; i--) {
      const e = L[i];
      if (dayOf(e[0]) !== today) break;
      ansT++;
      secT += e[4] / 10 + 4;
    }
    const P = { t: g ? g.t : 'none', due, introT, ansT, minT: Math.round(secT / 60), sp };
    let remaining = null,
      need = 0,
      days = null,
      buffer = 0;
    /* words below the starting level count as known; a goal below it is already reached */
    if (g && g.t !== 'none') {
      const lo = baseLevel(),
        tw = g.lv >= lo ? DATA.filter(d => d.l <= g.lv && d.l >= lo) : [];
      remaining = tw.filter(d => !mem[d.id]).length;
      days = daysTo(g.date);
      buffer =
        g.t === 'exam'
          ? Math.min(7, Math.floor(Math.max(0, days) / 4))
          : Math.min(3, Math.floor(Math.max(0, days) / 5));
      need = remaining ? Math.ceil(remaining / Math.max(1, days - buffer)) : 0;
      P.lv = g.lv;
      P.date = g.date;
    }
    P.remaining = remaining;
    P.need = need;
    P.days = days;
    const perNew = sp.neu + 2.5 * sp.rev;
    let nd;
    if (g && g.pace === 'min') nd = cl(Math.floor((g.n * 60 - load * sp.rev) / perNew), 0, 40);
    else if (g && g.pace === 'new') nd = g.n;
    else nd = remaining !== null ? cl(need, 3, 40) : 10;
    if (remaining === 0) nd = 0;
    if (g && g.t === 'exam' && days !== null && days <= 7) nd = 0;
    if (remaining !== null && remaining > 0) nd = Math.min(nd, remaining);
    P.newPerDay = nd;
    P.revPerDay = Math.round(load + nd * 2.5);
    P.minutes = Math.max(1, Math.round((P.revPerDay * sp.rev + nd * sp.neu) / 60));
    P.needMin = remaining ? minutesFor(remaining, load, sp, Math.max(1, days - buffer)) : null;
    P.newToday = Math.max(0, nd - introT);
    /* reviews today are capped by the daily time (or 1.5× a normal day), most at-risk first, so days off never pile up */
    let cap = Math.max(0, Math.max(20, Math.round(P.revPerDay * 1.5)) - ansT);
    if (g && g.pace === 'min') cap = Math.max(0, Math.floor((g.n * 60 - secT - P.newToday * sp.neu) / sp.rev));
    P.revToday = Math.min(due, cap);
    if (!g || g.t === 'none') P.status = 'free';
    else if (days < 0) P.status = 'past';
    else if (remaining === 0) P.status = 'review';
    else if (g.t === 'exam' && days <= 7) P.status = 'examweek';
    else {
      const fd = finishDays(g, nd, remaining, load, sp);
      P.finish = fd === null ? null : dayAfter(fd);
      P.status = fd !== null && fd <= days - buffer ? 'ok' : 'behind';
      /* a later date that works: at this pace, or (if the reviews would fill the time first) at 20 new words a day */
      if (P.status === 'behind') {
        const fdays = fd === null ? Math.ceil(remaining / 20) + buffer : fd + buffer;
        P.fixDate = fdays > days ? dayAfter(fdays) : null;
      }
    }
    if (isRest(today)) {
      P.rest = true;
      P.newToday = 0;
      P.revToday = 0;
    } /* 闭关: a meditation day has no plan */
    P.todayLeft = P.newToday * 2 + P.revToday;
    return P;
  }
  /* today's session: due reviews (most at risk first), up to three old green words to confirm, new words as cards
   (in curriculum order from the current level up to the goal's level) */
  function session(extra) {
    const P = plan(),
      t = now(),
      r = dr();
    const lo = curLevel(),
      src = tsort(DATA.filter(d => d.l >= lo && (!goal || goal.t === 'none' || d.l <= Math.max(goal.lv, lo))));
    let rev = [],
      conf = [];
    const all = [];
    for (const id in mem) {
      const e = mem[id];
      all.push([rNow(e, t), IDX.get(id), e]);
    }
    all.sort((a, b) => a[0] - b[0]);
    if (extra) {
      const td = dayOf(t);
      rev = all
        .filter(p => dayOf(p[2].w[2]) !== td)
        .slice(0, 12)
        .map(p => p[1]);
    } /* reviewing the same word again today adds little */ else {
      const pre = isRest(dayOf(t) + 1) ? 1440 : 0;
      rev = all
        .filter(p => rNow(p[2], t + pre) < r)
        .slice(0, P.revToday)
        .map(p => p[1]);
      conf = all
        .filter(p => p[2].L === 1 && levelOf(p[2]) > 13 && !rev.includes(p[1]))
        .sort((a, b) => levelOf(b[2]) - levelOf(a[2]))
        .slice(0, 3)
        .map(p => p[1]);
    }
    const fresh = pickNew(extra ? 5 : P.newToday, src);
    const q = rev.map(d => ({ k: 'q', d, q: pickType(d) }));
    conf.forEach(d => {
      const e = mem[d.id];
      if (!e.f) q.push({ k: 'q', d, q: 'f' });
      if (!e.s) q.push({ k: 'q', d, q: 's' });
    });
    const items = shuf(q),
      out = [];
    let k = 0;
    for (const d of fresh) {
      out.push(...items.splice(0, k ? 3 : 1));
      out.push({ k: 'card', d, isNew: true });
      k++;
    }
    return out.concat(items);
  }

  /* ---- insights for the Stats screen ---- */
  function insights() {
    const t = now(),
      L = allLog(),
      acc = {},
      cnt = {};
    let n7 = 0,
      ver = 0;
    for (let i = L.length - 1; i >= 0; i--) {
      const e = L[i];
      if (t - e[0] < 7 * 1440) n7++;
      if (!(e[6] & 1)) ver++;
      const q = e[2];
      if (QUIZ.has(q) && (cnt[q] || 0) < 150) {
        cnt[q] = (cnt[q] || 0) + 1;
        acc[q] = (acc[q] || 0) + (e[3] > 1 ? 1 : 0);
      }
    }
    const skills = {};
    for (const q of ['m', 'f', 's', 'l', 'c'])
      if (cnt[q]) skills[q] = { n: cnt[q], p: Math.round((acc[q] / cnt[q]) * 100) };
    let rs = 0,
      rn = 0;
    for (const id in mem) {
      rs += rNow(mem[id], t);
      rn++;
    }
    const pairs = [...confs()]
      .filter(p => p[1] >= 1)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([k, c]) => {
        const [a, b] = k.split('|');
        return [IDX.get(a), IDX.get(b), c];
      });
    const weak = Object.entries(skills)
      .filter(p => p[1].n >= 10)
      .sort((a, b) => a[1].p - b[1].p)[0];
    return {
      recall: rn ? Math.round((rs / rn) * 100) : null,
      n7,
      cal: calib(),
      skills,
      weak: weak && weak[1].p < 85 ? weak[0] : null,
      pairs,
      verified: ver,
      total: L.length,
      spaced: lossOf(W, seqs()).n,
      model: wMeta ? { n: wMeta.n, at: wMeta.at } : null,
      need: MINFIT,
    };
  }
  function updWeak() {
    const s = insights().skills,
      a = k => {
        const q = k === 'm' ? ['m'] : k === 'f' ? ['f', 'c'] : ['s', 'l'];
        let n = 0,
          p = 0;
        q.forEach(x => {
          if (s[x]) {
            n += s[x].n;
            p += s[x].p * s[x].n;
          }
        });
        return n >= 10 ? p / n / 100 : null;
      };
    for (const k of ['m', 'f', 's']) {
      const v = a(k);
      skillW[k] = v === null ? 0 : cl((0.9 - v) * 0.6, 0, 0.25);
    }
  }

  /* ---- personalising the model: fit the 19 parameters to this learner's own answers (on the phone) ---- */
  const MINFIT = 100; /* v1.13: from 100 spaced reviews (was 400), with a pull towards the defaults that fades with more data */
  function seqs() {
    const by = new Map();
    for (const e of allLog().slice(-12000)) {
      if (e[6] & 1) continue;
      const m = mem[e[1]];
      if (m && m.L) continue;
      let a = by.get(e[1]);
      if (!a) by.set(e[1], (a = []));
      a.push([e[0], e[3]]);
    }
    return [...by.values()];
  }
  function lossOf(w, S) {
    let ll = 0,
      n = 0;
    for (const q of S) {
      let st = null;
      for (const [t, g] of q) {
        if (st && !sameDay(t, st[2])) {
          const p = cl(Rt((t - st[2]) / 1440, st[1]), 1e-4, 1 - 1e-4);
          ll -= g > 1 ? Math.log(p) : Math.log(1 - p);
          n++;
        }
        st = step(w, st, g, t, 0);
      }
    }
    return { ll, n };
  }
  let fitting = false;
  async function optimize(force) {
    if (fitting) return null;
    const S = seqs(),
      base = lossOf(W0, S);
    if (base.n < MINFIT && !force) return null;
    if (!base.n) return null;
    fitting = true;
    try {
      const sc = W0.map(x => Math.max(0.05, Math.abs(x) * 0.5)),
        N = base.n;
      const toW = z => z.map((v, i) => cl(W0[i] + v * sc[i], LB[i], UB[i]));
      /* the penalty keeps the parameters near the defaults while there is little data: at 100 reviews moving one
         parameter by half its default value costs 0.3 nats per review, at 3,000 reviews only 0.01 */
      const f = z => lossOf(toW(z), S).ll / N + (30 / N) * z.reduce((s, v) => s + v * v, 0);
      let z = W0.map(() => 0),
        m = z.map(() => 0),
        v = z.map(() => 0),
        fz = f(z);
      const lr = 0.06,
        eps = 0.01;
      /* small slices of work between frames, so the app stays smooth while this runs */
      const idle = () =>
        new Promise(r =>
          window.requestIdleCallback ? requestIdleCallback(() => r(), { timeout: 250 }) : setTimeout(r, 16),
        );
      for (let it = 1; it <= 50; it++) {
        const g = [];
        for (let i = 0; i < 19; i++) {
          const z2 = z.slice();
          z2[i] += eps;
          g.push((f(z2) - fz) / eps);
          if (i % 4 === 3) await idle();
        }
        z = z.map((zi, i) => {
          m[i] = 0.9 * m[i] + 0.1 * g[i];
          v[i] = 0.999 * v[i] + 0.001 * g[i] * g[i];
          const mh = m[i] / (1 - Math.pow(0.9, it)),
            vh = v[i] / (1 - Math.pow(0.999, it));
          return zi - (lr * mh) / (Math.sqrt(vh) + 1e-8);
        });
        z = toW(z).map((w, i) => (w - W0[i]) / sc[i]);
        fz = f(z);
        await idle();
      }
      const w = toW(z),
        ll = lossOf(w, S).ll / N,
        ll0 = base.ll / N;
      ls.set('xc_fit', { at: now(), len: allLog().length });
      if (ll < ll0 - 0.002) {
        W = w.map(x => Math.round(x * 1e4) / 1e4);
        wMeta = { w: W, n: N, at: now(), ll: r3(ll), ll0: r3(ll0) };
        ls.set('xc_w', wMeta);
      }
      return { ll, ll0, n: N, used: ll < ll0 - 0.002 };
    } finally {
      fitting = false;
    }
  }
  /* ---- how good the memory model is for this learner ----
     Every spaced review (a word seen on an earlier day) is replayed through the model with the current parameters:
     the recall chance it predicted before the answer is set against what happened. Shown in Stats as predicted vs
     real recall, the average gap per band of predictions (calibration error) and the log loss. */
  function modelCheck() {
    const B = [
      [0, 0.5],
      [0.5, 0.7],
      [0.7, 0.8],
      [0.8, 0.9],
      [0.9, 1.01],
    ].map(([a, b]) => ({ a, b, n: 0, p: 0, y: 0 }));
    let n = 0,
      P = 0,
      Y = 0,
      ll = 0;
    for (const q of seqs()) {
      let st = null;
      for (const [t, g] of q) {
        if (st && !sameDay(t, st[2])) {
          const p = cl(Rt((t - st[2]) / 1440, st[1]), 1e-4, 1 - 1e-4),
            y = g > 1 ? 1 : 0;
          n++;
          P += p;
          Y += y;
          ll -= y ? Math.log(p) : Math.log(1 - p);
          const b = B.find(x => p >= x.a && p < x.b);
          b.n++;
          b.p += p;
          b.y += y;
        }
        st = step(W, st, g, t, 0);
      }
    }
    if (!n) return { n: 0 };
    return {
      n,
      pred: P / n,
      real: Y / n,
      ece: B.reduce((s, b) => s + Math.abs(b.p - b.y), 0) / n,
      ll: ll / n,
      own: !!wMeta,
      bins: B.filter(b => b.n >= 10).map(b => ({ a: b.a, b: Math.min(1, b.b), n: b.n, p: b.p / b.n, y: b.y / b.n })),
    };
  }
  function maybeOptimize() {
    const o = ls.get('xc_fit', null),
      L = allLog().length;
    if (o && (now() - o.at < 1440 || L - o.len < 100)) return;
    optimize(false).catch(() => {});
  }

  /* the gate opened and HSK 7–9 joined DATA: drop everything built from the word list */
  function bandAdded() {
    WD = null;
    PB = null;
    IX = null;
    TP = null;
    charS = null;
  }

  /* ---- backup, reset, history ---- */
  function exportMem() {
    flush();
    return mem;
  }
  /* extra: ids of HSK 7–9 words that are not loaded yet (a code from a learner past the gate) */
  function importMem(o, extra) {
    if (!o || typeof o !== 'object' || Array.isArray(o)) return null;
    const out = {};
    for (const id in o) {
      if (!IDX.has(id) && !(extra && extra.has(id))) continue;
      const c = cleanEntry(o[id]);
      if (c) out[id] = c;
    }
    return out;
  }
  function replace(m, g, w) {
    mem = m || {};
    if (g !== undefined) {
      goal = validGoal(g) ? g : null;
      ls.set('xc_goal', goal);
    }
    if (Array.isArray(w) && w.length === 19 && w.every((x, i) => Number.isFinite(x) && x >= LB[i] && x <= UB[i])) {
      W = w.slice();
      wMeta = { w: W, n: 0, at: now() };
      ls.set('xc_w', wMeta);
    }
    confMap = null;
    charS = null;
    last = null;
    sync();
  }
  function forget(id) {
    delete mem[id];
    charS = null;
    saveMem();
  }
  function clearLog() {
    logR = [];
    logA = [];
    logCache = null;
    confMap = null;
    last = null;
    ls.set('xc_log', []);
    ls.set('xc_logA', []);
    W = W0.slice();
    wMeta = null;
    ls.remove('xc_w');
    ls.remove('xc_fit');
    days0 = [];
    ls.remove('xc_days');
    skillW = { m: 0, f: 0, s: 0 };
  }

  sync();
  updWeak();
  return {
    now,
    dayOf,
    Rt,
    step,
    W0,
    get W() {
      return W;
    },
    levelOf,
    skLevel,
    okS,
    answer,
    undo,
    checkP,
    checkType,
    question,
    pickType,
    cardDeck,
    quizRound,
    exam,
    mockExam,
    mockScore,
    mockSave,
    get mocks() {
      return mocks;
    },
    MOCK_SEC,
    session,
    plan,
    dr,
    isoDay,
    dayAfter,
    daysTo,
    validGoal,
    curLevel,
    baseLevel,
    realm,
    realmLevel,
    isFinal,
    gateOpen,
    gateSeen,
    bandAdded,
    stage,
    stability,
    stabWords,
    stabDone,
    btOpen,
    btReady,
    makeupOpen,
    btStart,
    btFinish,
    grades,
    GRADES,
    STRIKES,
    cutOf,
    limitOf,
    placementDone,
    ptOpen,
    ptRetakeUntil,
    pyCheck,
    modelCheck,
    canTest,
    nextTestAt,
    advice,
    forecast,
    btChance,
    daysToSolid,
    streak,
    studyDays,
    today: () => dayOf(now()),
    dayDate: d => new Date((d * 1440 + TZ) * 6e4 + EPOCH),
    noteTest,
    challenge,
    setRest,
    get rest() {
      return rest;
    },
    isRest,
    restGain,
    gainList,
    sinceLast,
    soul,
    solid,
    wdiff,
    markAmbiguous,
    testsReset() {
      tests = [];
      ls.set('xc_tests', tests);
    },
    get tests() {
      return tests;
    },
    restoreExtra,
    get level() {
      return lvInfo;
    },
    restoreLevel,
    ptStart,
    ptNext,
    ptAnswer,
    ptResult,
    PT,
    placementBank,
    get goal() {
      return goal;
    },
    setGoal(g) {
      goal = validGoal(g) ? g : null;
      ls.set('xc_goal', goal);
    },
    mem: id => mem[id],
    has: id => !!mem[id],
    rNow: id => rNow(mem[id], now()),
    nextDue(id) {
      const e = mem[id];
      if (!e) return null;
      return (e.w[2] + ivl(e.w[1], dr()) * 1440 - now()) / 1440;
    },
    insights,
    updWeak,
    optimize,
    maybeOptimize,
    lossOf,
    seqs,
    exportMem,
    importMem,
    replace,
    forget,
    clearLog,
    sync,
    flush,
    allLog,
    partners,
    setTts(f) {
      ttsReady = f;
    },
    clozeOK,
    markTone,
    bareSyl,
    get params() {
      return wMeta ? W : null;
    },
  };
})();
