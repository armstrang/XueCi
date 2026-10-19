/* ---------- the tribulation (雷劫): the breakthrough as a series of strikes (LM.btStart / LM.btFinish) ----------
   One strike per skill on the realm's own words — 识 meaning, 忆 pinyin typed from memory, 听 listening, 读 the word
   that fits a sentence, 速 meanings against the clock, 译 sentence translations (HSK 7–9) — with no feedback until the
   end. Every strike must hold (70 %) and the whole must reach the cut; the margin gives the foundation's quality. */
let bt = null;
const gradeH = (g, r) =>
  g
    ? `<span class="grade g${g}"><b lang="zh-CN">${LM.GRADES[g]}${RN[r]}</b><small>${GPY[g]} ${RPY[r]}</small></span>`
    : '';
const GPY = ['', 'xiàpǐn', 'zhōngpǐn', 'shàngpǐn', 'wánměi'];
/* v1.16 (Josh's list): every strike opens with a bolt of lightning across the screen and its seal character; a passed
   tribulation ends in a golden light. A fresh jagged path each time, ~0.6 s, opacity/transform only; with reduced
   motion just a soft fade, never a flicker. */
let boltEl = null;
function bolt(hz, gold) {
  if (!boltEl) {
    boltEl = document.createElement('div');
    boltEl.className = 'bolt';
    boltEl.setAttribute('aria-hidden', 'true');
    document.body.appendChild(boltEl);
  }
  const path = (x, y, steps, dx, dy) => {
    const p = [[x, y]];
    for (let k = 0; k < steps; k++) {
      y += dy * (0.6 + Math.random() * 0.8);
      x += (Math.random() - 0.5) * dx;
      p.push([x, y]);
    }
    return p;
  };
  const x0 = 22 + Math.random() * 56,
    main = path(x0, -4, 7, 16, 9),
    at = main[2 + Math.floor(Math.random() * 3)],
    side = path(at[0], at[1], 3, 12, 7),
    d = p => 'M' + p.map(q => q[0].toFixed(1) + ' ' + q[1].toFixed(1)).join('L');
  boltEl.innerHTML = gold
    ? ''
    : `<svg viewBox="0 0 100 100" preserveAspectRatio="none"><path class="b0" d="${d(main)}"/><path class="b1" d="${d(side)}"/></svg>${hz ? `<b lang="zh-CN">${hz}</b>` : ''}`;
  boltEl.style.setProperty('--bx', x0.toFixed(0) + '%');
  boltEl.classList.toggle('gold', !!gold);
  boltEl.classList.remove('on');
  void boltEl.offsetWidth;
  boltEl.classList.add('on');
  try {
    navigator.vibrate && navigator.vibrate(gold ? [0, 20, 60, 30] : [0, 28, 50, 16]);
  } catch (e) {}
  clearTimeout(boltEl.t);
  boltEl.t = setTimeout(() => boltEl.classList.remove('on'), gold ? 1100 : 700);
}
/* the strikes as a row of seals: done, current, still to come */
function strikeRow(st, cur) {
  return `<div class="strikes" aria-hidden="true">${st.strikes
    .filter(s => !s.skipped && s.n)
    .map(s => {
      const i = st.items.findIndex(x => x.strike === s.k),
        j = i + s.n,
        c = cur >= j ? ' done' : cur >= i ? ' cur' : '';
      return `<span class="stk${c}"><b lang="zh-CN">${s.hz}</b></span>`;
    })
    .join('')}</div>`;
}
function strikeResults(x) {
  return `<div class="stkres">${x.strikes
    .map(
      s =>
        `<div class="skrow${s.skipped ? ' skip' : s.pass ? ' ok' : ' ng'}"><span><b lang="zh-CN">${s.hz}</b> ${esc(L10.strike[s.k])}</span><span class="mbar"><span class="stack"><i style="width:${s.skipped || !s.n ? 0 : (s.right / s.n) * 100}%"></i></span></span><b>${s.skipped ? L10.strikeSkip : `${s.right}/${s.n}`}</b></div>`,
    )
    .join('')}</div>`;
}
function renderBt() {
  if (!bt) bt = { st: null, res: null };
  const r = LM.realm();
  clearTimeout(bt.tm);
  if (bt.res) {
    const x = bt.res,
      to = x.makeup ? 7 : x.r;
    view.innerHTML = x.pass
      ? `<div class="qcard sum btres pass"><div class="q">${x.makeup ? '补劫' : '突破'} · ${L10.btPassT}</div>${realmHead(to, true)}
        ${gradeH(x.grade, to)}<p class="sumnote">${esc(L10.gradeM[x.grade])}</p>
        <p class="sumnote">${L10.btPass(RN[to], esc(L10.realmM[to]))}</p><p class="sumnote">${L10.btScore(x.right, x.n)}</p>${strikeResults(x)}<button class="linkbtn btshare" id="btShare">${L10.shareGo} · ${esc(L10.shareT)} ›</button>
        <div class="sumbtns">${x.gate ? `<button class="next wide" id="btGate">${L10.gateGo}</button>` : `<button class="ghost" id="btHome">${L10.sumHome}</button><button class="next" id="btSoul">${L10.soulGo}</button>`}</div></div>`
      : `<div class="qcard sum btres"><div class="big t5" lang="zh-CN">未破</div><h3>${L10.btFailT}</h3><p class="sumnote">${L10.btFail(x.right, x.n, Math.round(x.need * 100))}</p>
        ${strikeResults(x)}<p class="sumnote">${
          x.strikes.some(s => !s.pass)
            ? L10.btFailStrike(
                x.strikes
                  .filter(s => !s.pass)
                  .map(s => s.hz)
                  .join(' '),
              )
            : ''
        } ${L10.btGrow}</p>
        ${
          x.weak.length
            ? `<div class="sumwords"><div class="lbl">${L10.btWeak}</div>${x.weak
                .slice(0, 12)
                .map(d => `<span class="wchip"><b>${hzH(d)}</b>${esc(M1(d))}</span>`)
                .join('')}</div>`
            : ''
        }
        <p class="gnote lockn">${LOCK}<span>${esc(L10.testNext(dateS(tDate(LM.nextTestAt()))))}</span></p>
        <div class="sumbtns"><button class="ghost" id="btHome">${L10.sumHome}</button>${x.weak.length ? `<button class="next" id="btPractice">${L10.btPractice}</button>` : `<button class="next" id="btSoul">${L10.soulGo}</button>`}</div></div>`;
    return;
  }
  if (!bt.st) {
    if (!LM.btOpen()) {
      const sb = LM.stability();
      view.innerHTML = `<div class="qcard ptintro">${realmHead(r)}${stageH(r)}<p class="sumnote">${sb.ok ? L10.btNotOpen : L10.btUnstable}</p><button class="next" id="btHome">${L10.sumHome}</button></div>`;
      return;
    }
    if (!LM.canTest()) {
      view.innerHTML = lockedH();
      return;
    }
    const mk = LM.makeupOpen(),
      L = mk ? 6 : LM.realmLevel(r),
      to = mk ? 7 : r + 1,
      cut = Math.round(LM.cutOf(L) * 100),
      list = LM.STRIKES.filter(s => (!s.band || L >= 7) && (!s.tts || ttsOK()));
    view.innerHTML = `<div class="qcard ptintro btintro"><div class="btpath"><span lang="zh-CN" style="color:${rc(r)}">${RN[r]}</span><i aria-hidden="true">→</i><span lang="zh-CN" style="color:${rc(to)}">${mk ? '补劫' : RN[to]}</span></div>
      <h3>${esc(mk ? L10.mkIntroT : L10.btIntroT(L10.realmM[to]))}</h3>
      <div class="stklist">${list.map(s => `<div class="stkrow"><b lang="zh-CN">${s.hz}</b><span><em>${esc(L10.strike[s.k])}</em><small>${s.n} ${esc(L10.strikeQ)}${s.timed ? ' · ' + L10.strikeTime(LM.limitOf(L)) : ''}</small></span></div>`).join('')}</div>
      <div class="btrules"><p>${L10.btRule(cut)}</p><p>${L10.btQuality}</p>${ttsOK() ? '' : `<p class="mute">${L10.strikeNoTts}</p>`}<p class="mute">${L10.btIntro2}</p></div>
      <button class="next" id="btBegin">${L10.btBegin}</button></div>`;
    return;
  }
  const st = bt.st,
    it = st.items[st.i];
  if (!it) {
    btDone();
    return;
  }
  if (!it.t0) it.t0 = performance.now();
  const S = st.strikes.find(s => s.k === it.strike),
    first = st.items.findIndex(x => x.strike === it.strike) === st.i;
  if (first && !it.bolted) {
    it.bolted = 1;
    bolt(S.hz);
  }
  const body =
    it.q === 'p'
      ? `<form class="pyform" id="btPyForm"><input class="pyin" id="btPyIn" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false" enterkeyhint="done" placeholder="${esc(L10.pyPh)}" aria-label="${esc(L10.qPy)}"><button class="next pygo" type="submit">${L10.pyCheck}</button></form><p class="pyhelp">${L10.pyHelp}</p>`
      : `<div class="opts" id="btOpts">${it.opts.map((o, i) => `<button data-b="${i}">${i + 1}. ${qLab(o, it.q)}</button>`).join('')}</div>`;
  view.innerHTML = `<div class="fcmeta"><span>${L10.qN(st.i + 1, st.items.length)}</span>${progH(st.i, st.items.length)}</div>${strikeRow(st, st.i)}
    <div class="stkhead"><b lang="zh-CN">${S.hz}</b> ${esc(L10.strike[S.k])}</div>
    ${it.limit ? `<div class="tbar" aria-hidden="true"><i style="animation-duration:${it.limit}s"></i></div>` : ''}
    <div class="qcard qt-${it.q}">${qPrompt(it.d, it.q)}${body}
    <button class="idkbtn" id="btIdk">${L10.idk}</button></div>`;
  if (it.q === 'p') setTimeout(() => $('btPyIn')?.focus({ preventScroll: true }), 60);
  if (it.q === 'l' && ttsOK())
    setTimeout(() => {
      const b = $('qSay');
      if (b && state.screen === 'bt') speak(it.d.h, b);
    }, 250);
  if (it.limit)
    bt.tm = setTimeout(() => {
      if (state.screen === 'bt' && bt && bt.st === st && st.items[st.i] === it && !it.busy) btPick(-3);
    }, it.limit * 1000);
}
/* i: an option, −1 don't know, −2 typed right, −3 out of time, −4 typed wrong */
function btPick(i) {
  const st = bt && bt.st,
    it = st && st.items[st.i];
  if (!it || it.busy) return;
  it.busy = true;
  clearTimeout(bt.tm);
  const late = it.limit && performance.now() - it.t0 > it.limit * 1000 + 150;
  const r = late || i === -3 ? 'to' : i === -1 ? 'idk' : i === -2 || i === it.ans ? 'ok' : 'ng',
    x = r === 'ng' && i >= 0 && it.q !== 's' && it.q !== 't' ? it.opts[i].id : 0;
  it.r = r;
  if (r === 'ok') st.right++;
  LM.answer(it.d, { q: it.q, ok: r === 'ok', ms: performance.now() - it.t0, x, exam: true });
  studied();
  (i >= 0 ? document.querySelector(`#btOpts [data-b="${i}"]`) : $('btIdk'))?.classList.add('pick');
  setTimeout(() => {
    if (!bt || bt.st !== st) return;
    st.i++;
    if (st.i >= st.items.length) btDone();
    else {
      renderBt();
      window.scrollTo(0, 0);
    }
  }, 160);
}
function btDone() {
  clearTimeout(bt.tm);
  bt.res = LM.btFinish(bt.st);
  renderCurLv();
  if (bt.res.pass) {
    window.mmFeedback && mmFeedback(true);
    bolt(null, true);
    if (!bt.res.gate) {
      const l = LM.baseLevel();
      if (l !== state.level) setLevel(l);
      else refresh();
      toast(L10.btToast(RN[bt.res.r]));
    }
  } else refresh();
  renderBt();
  window.scrollTo(0, 0);
}
view.addEventListener('click', e => {
  if (state.screen !== 'bt') return;
  const id = e.target.closest('[id]')?.id;
  if (id === 'btBegin') {
    if (LM.btOpen() && LM.canTest()) bt.st = LM.btStart();
    renderBt();
    return;
  }
  if (id === 'btHome' || id === 'tHome') {
    go('home');
    return;
  }
  if (id === 'btSoul') {
    go('soul');
    return;
  }
  if (id === 'btShare') {
    openShare();
    return;
  }
  if (id === 'btGate') {
    openGate(true);
    return;
  }
  if (id === 'btPractice') {
    pendingRun = { mode: 'quiz', items: bt.res.weak.slice(0, 12).map(d => ({ k: 'q', d, q: LM.pickType(d) })) };
    go('quiz');
    return;
  }
  if (id === 'btIdk') {
    btPick(-1);
    return;
  }
  const b = e.target.closest('[data-b]');
  if (b) btPick(+b.dataset.b);
});
view.addEventListener('submit', e => {
  if (e.target.id !== 'btPyForm' || state.screen !== 'bt') return;
  e.preventDefault();
  const st = bt && bt.st,
    it = st && st.items[st.i],
    v = $('btPyIn')?.value || '';
  if (!it || it.busy || !v.trim()) return;
  btPick(LM.pyCheck(it.d, v).ok ? -2 : -4);
});
