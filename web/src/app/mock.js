/* ---------- HSK simulation (v1.17, Josh: a mock exam with automatic correction at the end and advice) ----------
   A quiz type ('mock'). The exam is built by LM.mockExam(level) like the HSK: 听力 listening, 阅读 reading, 书写
   writing, each part opened by a short card, one clock for the whole exam, no feedback until the end (run.exam).
   At the end everything is corrected at once: each part out of 100, the total against the pass mark, every question
   with the learner's answer and the right one, and advice drawn from the mistakes (weakest part, sentence gaps,
   tones, older words, time) with buttons that practise exactly those words. Results are kept in xc_mock (LM). */
const PART = {
  listen: ['听力', 'tīnglì'],
  read: ['阅读', 'yuèdú'],
  write: ['书写', 'shūxiě'],
};
const mmss2 = s => `${(s / 60) | 0}:${String(Math.round(s) % 60).padStart(2, '0')}`;
function mockMake(lv) {
  const m = LM.mockExam(lv);
  m.started = false;
  m.shown = new Set();
  return m;
}
/* the start card: level, the three parts, the time, the pass mark, the rules */
function renderMockIntro() {
  const m = run.mock,
    S = LM.MOCK_SEC,
    rows = m.parts
      .map(p => {
        const its = m.items.filter(it => it.part === p.k),
          sec = its.reduce((a, it) => a + S[it.q], 0);
        return `<div class="stkrow"><b lang="zh-CN">${PART[p.k][0][0]}</b><span><em>${PART[p.k][0]} ${esc(L10.partN[p.k])}</em><small>${esc(L10.mkRows(p.n, Math.round(sec / 60)))}</small></span></div>`;
      })
      .join('');
  const prev = LM.mocks.filter(x => x[1] === m.L).slice(-1)[0];
  view.innerHTML =
    runHead() +
    `<div class="qcard ptintro mkintro"><div class="btpath"><span lang="zh-CN">模拟考试</span></div>
    <h3>${esc(L10.mkIntroT(m.L))}</h3><p class="sumnote">${esc(L10.mkIntro)}</p>
    <div class="stklist">${rows}</div>
    <div class="btrules"><p>${esc(L10.mkTime(Math.round(m.sec / 60)))} · ${esc(L10.mkPass(m.parts.length * 60, m.parts.length * 100))}</p>
    ${m.parts.some(p => p.k === 'write') ? `<p class="mute">${esc(L10.mkWriteNote)}</p>` : ''}${m.skipped ? `<p class="mute">${esc(L10.mkNoTts)}</p>` : ''}
    ${prev ? `<p class="mute">${esc(L10.mkLast(prev[2], prev[3], dateS(tDate(prev[0]))))}</p>` : ''}<p class="mute">${esc(L10.mkNote)}</p></div>
    <button class="next" id="mkStart">${esc(L10.mkStart)}</button></div>`;
}
/* between parts: which part, how many questions */
function renderMockPart(k) {
  const m = run.mock,
    i = m.parts.findIndex(p => p.k === k),
    p = m.parts[i];
  view.innerHTML =
    runHead() +
    `<div class="qcard ptintro mkpart"><div class="big t1" lang="zh-CN">${PART[k][0]}</div><div class="mkpy">${PART[k][1]}</div>
    <h3>${esc(L10.mkPartT(i + 1, m.parts.length))} · ${esc(L10.partN[k])}</h3><p class="sumnote">${esc(L10.mkPartD[k](p.n))}</p>
    <button class="next" id="mkPartGo">${esc(L10.mkPartGo)}</button></div>`;
  $('mkPartGo')?.focus({ preventScroll: true });
}
function mockStart() {
  const m = run.mock;
  m.started = true;
  m.t0 = Date.now();
  run.end = Date.now() + m.sec * 1000;
  run.timer = setInterval(tick, 1000);
  renderRun();
}
/* the header during the exam: part, clock, question count (no type menu: leaving is the back button) */
function mockHead() {
  const m = run.mock,
    it = run.items[run.i],
    n = run.items.length;
  if (!m.started || !it) return null;
  const k = it.part,
    its = m.items.filter(x => x.part === k),
    j = its.indexOf(it) + 1;
  return `<div class="qhead mkhd"><div class="mksec"><b lang="zh-CN">${PART[k][0]}</b> ${esc(L10.partN[k])} <small>${j}/${its.length}</small></div><div class="score"><span class="timer" id="exTimer">${clock()}</span><span>${L10.qN(run.i + 1, n)}</span></div></div>`;
}

/* ---- the correction ---- */
function mockAnswerH(it, o) {
  if (!o) return `<i class="mkno">${esc(it.pick === -1 ? L10.mkIdk : L10.mkNone)}</i>`;
  return it.q === 'm' ? esc(M1(o)) : it.q === 't' ? esc(TR(o)) : `<span lang="zh-CN">${esc(o.h)}</span>`;
}
function mockRowH(it, no) {
  const d = it.d,
    q = it.q;
  const ask =
    q === 'l'
      ? `${spk(d.h, ' sm')} <small>${esc(L10.tListen)}</small>`
      : q === 'm'
        ? `<b lang="zh-CN">${esc(d.h)}</b>`
        : q === 'c'
          ? `<span lang="zh-CN">${gapZ(d)}</span>`
          : q === 't'
            ? `<span lang="zh-CN">${esc(d.z)}</span>`
            : esc(M1(d));
  const right =
    q === 'm'
      ? esc(M1(d))
      : q === 't'
        ? esc(TR(d))
        : q === 'p'
          ? `<span class="pyline">${pyH(d)}</span>`
          : `<span lang="zh-CN">${esc(d.h)}</span>`;
  const mine =
    q === 'p'
      ? it.typed
        ? `<span class="pyline">${esc(it.typed)}</span>`
        : `<i class="mkno">${esc(it.pick === -3 && it.typed === '' ? L10.mkIdk : L10.mkNone)}</i>`
      : mockAnswerH(it, it.opts && it.pick >= 0 ? it.opts[it.pick] : null);
  return `<div class="mkrow ${it.ok ? 'ok' : 'ng'}"><span class="mkn" aria-hidden="true">${no}</span><div class="mkbody">
    <div class="mkask"><small>${esc(TNAME()[q])}</small> ${ask}</div>
    ${it.ok ? `<div class="mkans ok">✓ ${right}</div>` : `<div class="mkans ng"><span>${esc(L10.mkYour)}:</span> ${mine}</div><div class="mkans ok"><span>${esc(L10.mkAns)}:</span> ${right}</div>`}
    ${it.ok ? '' : `<div class="mkword"><span class="hz" lang="zh-CN">${hzH(d)}</span> <span class="py">${pyH(d)}</span> · ${esc(M1(d))} ${spk(d.h, ' sm')}</div>`}
  </div></div>`;
}
/* advice from the mistakes; each may carry a practice round */
function mockAdvice(m, r) {
  const out = [],
    L = m.L,
    wrong = m.items.filter(it => !it.ok),
    pct = r.total / r.max,
    next = LEVELS.includes(L + 1) ? L + 1 : 0;
  if (r.pass && pct >= 0.85) out.push({ t: L10.mkA.top(L, next), b: next ? ['next', L10.mkA.nextBtn(next)] : null });
  else if (r.pass) out.push({ t: L10.mkA.pass });
  else if (pct >= 0.5) out.push({ t: L10.mkA.near(r.need - r.total) });
  else out.push({ t: L10.mkA.low(L), b: ['plan', L10.mkA.planBtn] });
  const weak = r.parts.slice().sort((a, b) => a.score - b.score)[0];
  if (weak && weak.score < 85 && r.parts.length > 1)
    out.push({ t: L10.mkA.part[weak.k](weak.score), b: ['part:' + weak.k, L10.mkA.partBtn] });
  const ng = q => wrong.filter(it => it.q === q).length,
    of = q => m.items.filter(it => it.q === q).length;
  if (of('c') && ng('c') / of('c') >= 0.34) out.push({ t: L10.mkA.cloze });
  if (of('t') && ng('t') / of('t') >= 0.34) out.push({ t: L10.mkA.trans });
  const py = wrong.filter(it => it.q === 'p' && it.typed);
  if (py.length && py.some(it => plain(it.typed.replace(/[1-5]/g, '')) === plain(it.d.p)))
    out.push({ t: L10.mkA.tone });
  const older = wrong.filter(it => it.d.l < L).length;
  if (older >= 2) out.push({ t: L10.mkA.older(older, L) });
  if (run.timeUp) out.push({ t: L10.mkA.time, b: ['exam', L10.mkA.examBtn] });
  else if (m.used < m.sec * 0.35 && pct < 0.7) out.push({ t: L10.mkA.fast });
  if (wrong.length) out.push({ t: L10.mkA.wrong(wrong.length), b: ['wrong', L10.mkA.wrongBtn(wrong.length)] });
  return out;
}
function renderMockResult() {
  const m = run.mock;
  if (!m.r) {
    m.used = Math.min(m.sec, (Date.now() - m.t0) / 1000);
    m.r = LM.mockScore(m);
    m.prev = LM.mocks.filter(x => x[1] === m.L).slice(-1)[0] || null;
    LM.mockSave(m, m.r, m.used);
    m.adv = mockAdvice(m, m.r);
    LM.updWeak();
  }
  const r = m.r,
    ok = r.pass;
  const parts = r.parts
    .map(
      p =>
        `<div class="skrow mkp ${p.score >= 60 ? 'ok' : 'ng'}"><span><b lang="zh-CN">${PART[p.k][0]}</b> ${esc(L10.partN[p.k])}</span><span class="mbar"><span class="stack"><i style="width:${p.score}%"></i></span></span><b>${p.score}</b></div><div class="mkpn">${esc(L10.mkRight(p.right, p.n))}</div>`,
    )
    .join('');
  const cmp = m.prev ? `<p class="sumnote">${esc(L10.mkA.cmp(r.total - m.prev[2], dateS(tDate(m.prev[0]))))}</p>` : '';
  const adv = m.adv
    .map(
      (a, i) =>
        `<div class="mkadv"><span class="mkai" aria-hidden="true">${i + 1}</span><p>${esc(a.t)}</p>${a.b ? `<button class="ghost" data-mk="${a.b[0]}">${esc(a.b[1])}</button>` : ''}</div>`,
    )
    .join('');
  let no = 0;
  const rev = m.parts
    .map(p => {
      const its = m.items.filter(it => it.part === p.k),
        bad = its.filter(it => !it.ok).length;
      return `<details class="mkrev"${bad ? ' open' : ''}><summary><b lang="zh-CN">${PART[p.k][0]}</b> ${esc(L10.partN[p.k])} · ${esc(bad ? L10.mkWrongN(bad) : L10.mkAllRight)}</summary>${its.map(it => mockRowH(it, ++no)).join('')}</details>`;
    })
    .join('');
  const hist = LM.mocks
    .filter(x => x[1] === m.L)
    .slice(-6)
    .map(
      x =>
        `<span class="mkh ${x[2] >= x[3] * 0.6 ? 'ok' : 'ng'}" title="${esc(dateS(tDate(x[0])))}"><i style="height:${Math.max(6, (x[2] / x[3]) * 100)}%"></i><small>${x[2]}</small></span>`,
    )
    .join('');
  view.innerHTML =
    runHead() +
    `<div class="qcard sum mkres">
    <div class="mkhead"><div class="mklv" lang="zh-CN">模拟考试 · HSK ${m.L}</div>
      <div class="mktotal ${ok ? 'pass' : 'fail'}"><b>${r.total}</b><small>/${r.max}</small></div>
      <div class="mkverdict ${ok ? 'pass' : 'fail'}">${esc(ok ? L10.mkPassY : L10.mkPassN)}</div>
      <p class="sumnote">${esc(L10.mkNeed(r.need, r.max))} · ${esc(L10.mkUsed(mmss2(m.used), mmss2(m.sec)))}${run.timeUp ? ' · ' + esc(L10.timeUp) : ''}</p></div>
    <div class="mkparts">${parts}</div>${cmp}
    <h4 class="mkt">${esc(L10.mkAdvT)}</h4><div class="mkadvs">${adv}</div>
    <h4 class="mkt">${esc(L10.mkRevT)}</h4>${rev}
    ${hist ? `<h4 class="mkt">${esc(L10.mkHistT)}</h4><div class="mkhist" aria-hidden="true">${hist}</div>` : ''}
    <p class="gnote">${esc(L10.mkNote)}</p>
    <div class="sumbtns"><button class="ghost" id="sumHome">${L10.sumHome}</button><button class="next" id="mkAgain">${esc(L10.mkAgain)}</button></div></div>`;
}
/* a practice round from the exam's mistakes (the quiz type goes back to guided, so the round is a normal one) */
function mockPractice(items) {
  if (!items.length) return;
  pendingRun = {
    mode: 'quiz',
    items: items.map(it => ({ k: 'q', d: it.d, q: it.q === 'l' && !ttsOK() ? 'm' : it.q })),
  };
  qType = 'auto';
  saveUI();
  resetRun();
  renderRun();
  window.scrollTo(0, 0);
}
view.addEventListener('click', e => {
  if (state.screen !== 'quiz' || !run || !run.mock) return;
  const m = run.mock,
    id = e.target.closest('[id]')?.id;
  if (id === 'mkStart' && !m.started) {
    mockStart();
    return;
  }
  if (id === 'mkPartGo') {
    m.shown.add(run.items[run.i]?.part);
    renderRun();
    window.scrollTo(0, 0);
    return;
  }
  if (id === 'mkAgain') {
    resetRun();
    renderRun();
    window.scrollTo(0, 0);
    return;
  }
  const b = e.target.closest('[data-mk]');
  if (!b || !m.r) return;
  const k = b.dataset.mk,
    wrong = m.items.filter(it => !it.ok);
  if (k === 'wrong') mockPractice(wrong);
  else if (k.startsWith('part:')) mockPractice(wrong.filter(it => it.part === k.slice(5)));
  else if (k === 'exam' || k === 'next') {
    if (k === 'next') setLevel(m.L + 1);
    qType = k === 'exam' ? 'exam' : 'mock';
    saveUI();
    resetRun();
    renderRun();
    window.scrollTo(0, 0);
  } else if (k === 'plan') go('home');
});
