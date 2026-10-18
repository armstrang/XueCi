/* ---------- breakthrough (突破): 20 questions on the realm's words, no feedback until the end (LM.btStart/btFinish) ---------- */
let bt = null;
function renderBt() {
  if (!bt) bt = { st: null, res: null };
  const r = LM.realm();
  if (bt.res) {
    const x = bt.res;
    view.innerHTML = x.pass
      ? `<div class="qcard sum btres pass"><div class="q">突破 · ${L10.btPassT}</div>${realmHead(x.r, true)}<p class="sumnote">${L10.btPass(RN[x.r], esc(L10.realmM[x.r]))}</p><p class="sumnote">${L10.btScore(x.right, x.n)}</p>
        <div class="sumbtns"><button class="ghost" id="btHome">${L10.sumHome}</button><button class="next" id="btSoul">${L10.soulGo}</button></div></div>`
      : `<div class="qcard sum btres"><div class="big t5" lang="zh-CN">未破</div><h3>${L10.btFailT}</h3><p class="sumnote">${L10.btFail(x.right, x.n, Math.round(x.need * 100))}</p><p class="sumnote">${L10.btGrow}</p>
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
      view.innerHTML = `<div class="qcard ptintro">${realmHead(r)}${stageH(r)}<p class="sumnote">${L10.btNotOpen}</p><button class="next" id="btHome">${L10.sumHome}</button></div>`;
      return;
    }
    if (!LM.canTest()) {
      view.innerHTML = lockedH();
      return;
    }
    view.innerHTML = `<div class="qcard ptintro btintro"><div class="btpath"><span lang="zh-CN" style="color:${rc(r)}">${RN[r]}</span><i aria-hidden="true">→</i><span lang="zh-CN" style="color:${rc(r + 1)}">${RN[r + 1]}</span></div>
      <h3>${esc(L10.btIntroT(L10.realmM[r + 1]))}</h3><p class="sumnote">${L10.btIntro(realmLv(r) >= 5 ? 80 : 75)}</p><p class="sumnote">${L10.btIntro2}</p>
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
  view.innerHTML = `<div class="fcmeta"><span>${L10.qN(st.i + 1, st.items.length)}</span>${progH(st.i, st.items.length)}</div>
    <div class="qcard qt-${it.q}">${qPrompt(it.d, it.q)}<div class="opts" id="btOpts">${it.opts.map((o, i) => `<button data-b="${i}">${i + 1}. ${qLab(o, it.q)}</button>`).join('')}</div>
    <button class="idkbtn" id="btIdk">${L10.idk}</button></div>`;
}
function btPick(i) {
  const st = bt && bt.st,
    it = st && st.items[st.i];
  if (!it || it.busy) return;
  it.busy = true;
  const r = i < 0 ? 'idk' : i === it.ans ? 'ok' : 'ng',
    x = r === 'ng' && it.q !== 's' ? it.opts[i].id : 0;
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
  bt.res = LM.btFinish(bt.st);
  renderCurLv();
  if (bt.res.pass) {
    window.mmFeedback && mmFeedback(true);
    const l = LM.baseLevel();
    if (l !== state.level) setLevel(l);
    else refresh();
    toast(L10.btToast(RN[bt.res.r]));
  } else refresh();
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
