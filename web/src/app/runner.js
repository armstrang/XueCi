/* ---------- practice: Cards, Quiz and today's session share one runner ----------
   A run is a list of items: cards ({k:'card'}) and questions ({k:'q', q: m|f|s|l|c}). Answers go to LM.answer,
   which updates the memory model, the 0–20 level and the answer log. Wrong answers come back a few items later. */
let run = null,
  sessionExtra = false,
  pendingRun = null; /* pendingRun {mode, items}: a ready-made round (today's trial, words to strengthen) */
const EXAM_N = 20,
  EXAM_SEC = 300,
  ROUND_Q = 12,
  ROUND_C = 20;
function resetRun() {
  if (run && run.timer) clearInterval(run.timer);
  if (run && run.brT) clearInterval(run.brT);
  run = null;
}
const startCards = resetRun,
  startQuiz = resetRun; /* level/unit change, restore and reset start a fresh run */
function ttsOK() {
  try {
    if (window.MMAndroid && typeof MMAndroid.ttsStatus === 'function') return MMAndroid.ttsStatus() === 'ready';
    return (
      'speechSynthesis' in window &&
      speechSynthesis.getVoices().some(v => /^zh[-_]?(CN|Hans)?/i.test(v.lang) && !/TW|HK/i.test(v.lang))
    );
  } catch (e) {
    return false;
  }
}
LM.setTts(ttsOK);
function makeRun(mode) {
  resetRun();
  let items,
    exam = false,
    lv = state.level;
  if (pendingRun && pendingRun.mode === mode) {
    items = pendingRun.items;
    pendingRun = null;
  } else if (mode === 'card') items = LM.cardDeck(pool(), ROUND_C).map(d => ({ k: 'card', d }));
  else if (mode === 'session') items = LM.session(sessionExtra);
  else if (qType === 'exam') {
    exam = true;
    items = LM.exam(lv, EXAM_N);
  } else items = LM.quizRound(pool(), ROUND_Q, qType === 'auto' ? null : qType);
  run = {
    mode,
    items,
    i: 0,
    ok: 0,
    tot: 0,
    before: new Map(),
    wrong: new Map(),
    conf: [],
    again: new Map(),
    exam,
    lv,
    over: 0,
  };
  if (exam) {
    run.end = Date.now() + EXAM_SEC * 1000;
    run.timer = setInterval(tick, 1000);
  }
}
function renderRun() {
  if (!run) makeRun(state.screen);
  if (run.brk) {
    renderBreak();
    return;
  }
  const it = run.items[run.i];
  if (!it) {
    renderSummary();
    return;
  }
  if (!run.exam && !it.st && !it.opts) {
    const f = fatigue();
    if (f) {
      sit.shown = true;
      run.brk = { f };
      renderBreak();
      return;
    }
  }
  if (!run.before.has(it.d.id)) run.before.set(it.d.id, lvl(it.d));
  if (it.k === 'card') renderCardItem(it);
  else renderQItem(it);
}
function nextItem() {
  run.i++;
  renderRun();
  window.scrollTo(0, 0);
}

/* ---- rest (调息): a "sitting" is a run of answers with no gap over 10 minutes. Tiredness shows as falling accuracy
   (last 10 answers 15+ points below the first 10), slower answers (median time ×1.4) or a long sitting (25 min);
   then, once per sitting, a short break is offered — never forced. */
let sit = { t0: 0, last: 0, ans: [], shown: false, brk: null };
const accOf = a => (a.length ? Math.round((a.reduce((x, y) => x + y[0], 0) / a.length) * 100) : 0);
function noteAns(ok, ms) {
  const t = Date.now();
  if (!sit.last || t - sit.last > 6e5) sit = { t0: t, last: t, ans: [], shown: false, brk: null };
  sit.last = t;
  sit.ans.push([ok ? 1 : 0, Math.min(6e4, ms || 0)]);
}
function fatigue() {
  const a = sit.ans;
  if (sit.shown || a.length < 20 || Date.now() - sit.last > 6e5) return null;
  const f = a.slice(0, 10),
    l = a.slice(-10),
    med = x => {
      const m = x.map(y => y[1]).sort((p, q) => p - q);
      return (m[4] + m[5]) / 2;
    },
    A = accOf(f),
    B = accOf(l);
  if (A - B >= 15) return { k: 'acc', a: A, b: B };
  if (med(l) >= 1.4 * Math.max(1500, med(f))) return { k: 'slow' };
  const m = Math.round((Date.now() - sit.t0) / 6e4);
  return m >= 25 ? { k: 'time', m } : null;
}
const mmss = x => `${(x / 60) | 0}:${String(x % 60).padStart(2, '0')}`;
function renderBreak() {
  const b = run.brk,
    f = b.f,
    left = b.end ? Math.max(0, Math.ceil((b.end - Date.now()) / 1000)) : 300,
    done = !!b.end && left <= 0;
  const why = f.k === 'acc' ? L10.brAcc(f.a, f.b) : f.k === 'slow' ? L10.brSlow : L10.brTime(f.m);
  view.innerHTML = `<div class="qcard sum restcard"><div class="big t4" lang="zh-CN">调息</div><h3>${b.end ? (done ? L10.brDone : L10.brT2) : L10.brT}</h3>
    ${
      b.end
        ? `<div class="breath">${done ? '' : '<div class="bcirc" aria-hidden="true"></div>'}<div class="btime" id="brTime" role="timer">${mmss(left)}</div><div class="bcue" id="brCue" aria-live="polite">${done ? '' : L10.brIn}</div></div>${done ? '' : `<p class="sumnote">${L10.brHow}</p>`}`
        : `<p class="sumnote">${why}</p><p class="sumnote">${L10.brWhy}</p>`
    }
    <div class="sumbtns${b.end ? '' : ' three'}"><button class="ghost" id="brStop">${L10.brStop}</button>${b.end ? '' : `<button class="ghost" id="brGo">${L10.brGo}</button>`}<button class="next" id="brSkip">${b.end ? L10.brCont : L10.brSkip}</button></div></div>`;
  $('brSkip')?.focus({ preventScroll: true });
}
function breakStart() {
  const b = run.brk;
  b.end = Date.now() + 300000;
  b.t0 = Date.now();
  renderBreak();
  run.brT = setInterval(() => {
    if (!run || run.brk !== b) return;
    const left = Math.max(0, Math.ceil((b.end - Date.now()) / 1000));
    if (left <= 0) {
      clearInterval(run.brT);
      run.brT = 0;
      renderBreak();
      window.mmFeedback && mmFeedback(true);
      return;
    }
    const el = $('brTime'),
      cue = $('brCue');
    if (el) el.textContent = mmss(left);
    if (cue) cue.textContent = Math.floor((Date.now() - b.t0) / 4000) % 2 ? L10.brOut : L10.brIn;
  }, 1000);
}
function breakEnd(stop) {
  if (run.brT) {
    clearInterval(run.brT);
    run.brT = 0;
  }
  const b = run.brk;
  run.brk = null;
  if (b && b.end) sit.brk = { at: sit.ans.length, acc: accOf(sit.ans.slice(-10)) };
  if (stop) run.i = run.items.length;
  renderRun();
  window.scrollTo(0, 0);
}
/* bring a word back a few items later (at most twice per word in a run) */
function again(item, copy) {
  const n = run.again.get(item.d.id) || 0;
  if (n >= 2 || run.exam) return;
  run.again.set(item.d.id, n + 1);
  run.items.splice(Math.min(run.items.length, run.i + 4), 0, copy);
}
const progH = (i, n) =>
  `<span class="mbar"><span class="stack"><i style="width:${Math.min(100, (i / Math.max(1, n)) * 100)}%;background:var(--acc)"></i></span></span>`;
const TNAME = () => ({ m: L10.tMean, f: L10.tHz, s: L10.tTone, l: L10.tListen, c: L10.tCloze });
function qtList() {
  return [
    ['auto', L10.tAuto, L10.dAuto, '智'],
    ['m', L10.tMean, L10.dMean, '汉→a'],
    ['f', L10.tHz, L10.dHz, 'a→汉'],
    ['s', L10.tTone, L10.dTone, 'mā'],
    ...(canSpeak() ? [['l', L10.tListen, L10.dListen, '♪→汉']] : []),
    ['c', L10.tCloze, L10.dCloze, '汉＿'],
    ['exam', L10.tExam, L10.dExam(EXAM_N, EXAM_SEC / 60), '考'],
  ];
}
function clock() {
  const s = run && run.end ? Math.max(0, Math.ceil((run.end - Date.now()) / 1000)) : 0;
  return `${(s / 60) | 0}:${String(s % 60).padStart(2, '0')}`;
}
function tick() {
  if (!run || !run.exam) return;
  const el = $('exTimer');
  if (el) el.textContent = clock();
  if (Date.now() >= run.end) {
    clearInterval(run.timer);
    run.timer = 0;
    run.timeUp = true;
    run.i = run.items.length;
    if (state.screen === 'quiz') renderRun();
  }
}
function runHead() {
  const n = run.items.length,
    i = Math.min(run.i + 1, n),
    it = run.items[run.i];
  if (run.mode === 'card') return `<div class="fcmeta"><span>${L10.cardN(i, n)}</span>${progH(run.i, n)}</div>`;
  if (run.mode === 'session') {
    const lab = !it || it.k === 'card' ? '' : TNAME()[it.q]; /* a card shows "new word" or its level on its face */
    return `<div class="fcmeta"><span>${L10.qN(i, n)}</span><span class="tlabel">${esc(lab)}</span>${progH(run.i, n)}</div>`;
  }
  const QT = qtList(),
    cur = QT.find(q => q[0] === qType) || QT[0];
  return `<div class="qhead"><div class="qsel" id="qsel">
      <button class="qtbtn" id="qTypeBtn" aria-haspopup="listbox" aria-expanded="false" aria-label="${L10.qTypeL}: ${cur[1]}"><span class="qti">${cur[3]}</span><span class="qtl">${cur[1]}</span>${CHEV}</button>
      <div class="menu qmenu" id="qTypeMenu" role="listbox" aria-label="${L10.qTypeL}" hidden>${QT.map(q => `<button class="qtrow" role="option" data-qt="${q[0]}" aria-selected="${q[0] === qType}"><span class="qti">${q[3]}</span><span class="nm"><b>${q[1]}</b><small>${q[2]}</small></span>${CHECK}</button>`).join('')}</div>
     </div><div class="score">${
       run.exam
         ? `<span class="timer" id="exTimer">${clock()}</span><span>${L10.qN(i, n)}</span>`
         : `<span>${L10.qN(i, n)}</span><span>${L10.right} <b>${run.ok}</b>/${run.tot}</span>`
     }</div></div>`;
}
