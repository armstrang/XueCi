/* ---------- placement test: 50 quick questions that adapt to the answers (LM.ptStart/ptNext/ptAnswer/ptResult) ---------- */
let pt = null;
function renderPlacement() {
  if (!pt) pt = { st: null, it: null, res: null };
  if (pt.res) {
    /* the result: the realm, where the test puts you inside it (the stage bar counts the test's estimate), and the
       estimate per HSK level */
    const r = pt.res,
      R = LM.realm();
    view.innerHTML = `<div class="qcard sum ptres"><div class="q">${L10.ptResT}</div>${realmHead(R, true)}
      <p class="sumnote">${r.m ? L10.ptResM(r.m) : L10.ptRes0}</p>${R >= 1 && R <= 6 ? stageH(R) : ''}<div class="glbl">${L10.ptPer}</div>${perBars(r.per)}
      <p class="sumnote">${L10.ptResN(r.right, r.n, r.idk)}</p>
      <div class="sumbtns"><button class="ghost" id="ptHome">${L10.sumHome}</button><button class="next" id="ptGoal">${L10.ptGoal}</button></div>
      <button class="ghost wide soulbtn" id="ptSoul"><span lang="zh-CN">识海</span> ${L10.soulGo} ›</button></div>`;
    return;
  }
  if (!pt.st) {
    if (!LM.canTest()) {
      view.innerHTML = lockedH();
      return;
    }
    view.innerHTML = `<div class="qcard ptintro"><div class="big t3">测</div><h3>${L10.ptIntroT}</h3><p class="sumnote">${L10.ptIntro}</p><p class="sumnote">${L10.ptIntro2}</p>
      <button class="next" id="ptBegin">${L10.ptBegin}</button></div>`;
    return;
  }
  if (!pt.it) {
    pt.it = LM.ptNext(pt.st);
    if (!pt.it) {
      ptFinish();
      return;
    }
    pt.it.t0 = performance.now();
  }
  const it = pt.it,
    n = pt.st.items.length,
    N = LM.PT.N;
  view.innerHTML = `<div class="fcmeta"><span>${L10.qN(n + 1, N)}</span>${progH(n, N)}</div>
    <div class="qcard qt-${it.q}">${qPrompt(it.d, it.q)}<div class="opts" id="ptOpts">${it.opts.map((o, i) => `<button data-p="${i}">${i + 1}. ${qLab(o, it.q)}</button>`).join('')}</div>
    <button class="idkbtn" id="ptIdk">${L10.idk}</button></div>`;
}
function ptPick(i) {
  const it = pt && pt.it;
  if (!it || it.busy) return;
  it.busy = true;
  const r = i < 0 ? 'idk' : i === it.ans ? 'ok' : 'ng',
    ms = performance.now() - it.t0,
    x = r === 'ng' && it.q !== 's' ? it.opts[i].id : 0;
  LM.answer(it.d, { q: it.q, ok: r === 'ok', ms, x, placement: true });
  LM.ptAnswer(pt.st, it, r);
  studied();
  if (i >= 0) document.querySelector(`#ptOpts [data-p="${i}"]`)?.classList.add('pick');
  else $('ptIdk')?.classList.add('pick');
  setTimeout(() => {
    if (!pt || pt.it !== it) return;
    pt.it = null;
    if (pt.st.items.length >= LM.PT.N) ptFinish();
    else renderPlacement();
  }, 160);
}
function ptFinish() {
  const r = (pt.res = LM.ptResult(pt.st));
  LM.placementDone(r);
  resetRun();
  renderCurLv();
  const l = LM.baseLevel();
  if (l !== state.level) setLevel(l);
  else refresh();
  toast(L10.ptDone(RN[LM.realm()]));
}
view.addEventListener('click', e => {
  if (state.screen !== 'placement') return;
  const id = e.target.closest('[id]')?.id;
  if (id === 'ptBegin') {
    if (LM.canTest()) pt.st = LM.ptStart();
    renderPlacement();
    return;
  }
  if (id === 'ptHome' || id === 'tHome') {
    go('home');
    return;
  }
  if (id === 'ptSoul') {
    go('soul');
    return;
  }
  if (id === 'ptGoal') {
    const lv = LM.baseLevel();
    go('home');
    setTimeout(() => openGoal(false, lv), 300);
    return;
  }
  if (id === 'ptIdk') {
    ptPick(-1);
    return;
  }
  const b = e.target.closest('[data-p]');
  if (b) ptPick(+b.dataset.p);
});
