/* ---- cards: "Don't know" / "I know it" → a quick check (adaptive) → the back of the card ---- */
const pyOpt = a => esc(a.map((s, i) => (i && /^[aeoāáǎàēéěèōóǒò]/i.test(s) ? "'" : '') + s).join(''));
function backFace(d) {
  return `<div class="face back"><div class="head"><span class="hz">${hzH(d)}</span><span class="py">${pyH(d)}</span>${spk(d.h)}</div>
      <div class="mean">${mH(M(d))}</div><div class="ex"><div class="zh">${exH(d)}${spk(d.z, ' sm')}</div>${zpH(d)}<div class="id">${esc(TR(d))}</div></div></div>`;
}
function renderCardItem(it) {
  const d = it.d;
  if (!it.st) {
    it.st = 'front';
    it.t0 = performance.now();
    it.fresh = !LM.has(d.id);
  }
  view.innerHTML =
    runHead() +
    `<div class="flip${it.st === 'back' ? ' on' : it.st === 'check' ? ' checking' : ''}" id="flip"><div class="inner">
    <div class="face">${it.fresh ? `<span class="st newtag">${L10.newWord}</span>` : stH(d)}<div class="big">${esc(d.h)}</div>${spk(d.h, ' lg')}<div class="hint">${L10.fcHint}</div></div>
    ${backFace(d)}</div></div><div class="fcact" id="fcAct">${cardAct(it)}</div>`;
}
function cardAct(it) {
  if (it.st === 'front')
    return `<div class="fcbtns"><button class="no-btn" id="fcNo">${L10.fcDont}</button><button class="yes-btn" id="fcYes">${L10.fcKnow}</button></div>`;
  if (it.st === 'check') {
    const c = it.chk;
    return `<div class="chk"><div class="q">${c.q === 'cs' ? L10.chkTone : L10.chkMean}</div><div class="opts">${c.opts
      .map(
        (o, i) =>
          `<button data-c="${i}">${i + 1}. ${c.q === 'cs' ? `<span class="pyo">${pyOpt(o)}</span>` : esc(M1(o))}</button>`,
      )
      .join('')}</div></div>`;
  }
  const msg = { ok: L10.resOk, over: L10.resOver, no: L10.resNo, trust: L10.resTrust }[it.res];
  return `<div class="res ${it.res}" role="status">${msg}</div><div class="fcbtns${it.res === 'trust' ? '' : ' one'}">${it.res === 'trust' ? `<button class="no-btn" id="fcOops">${L10.oops}</button>` : ''}<button class="next" id="fcNext">${L10.next}</button></div>`;
}
/* keep the buttons under the card in view (small screens, large text) */
function inView(el) {
  if (!el) return;
  const r = el.getBoundingClientRect();
  if (r.bottom > innerHeight - 8)
    el.scrollIntoView({
      block: 'end',
      behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
    });
}
function cardShow(it, ok) {
  it.st = 'back';
  run.tot++;
  if (ok) run.ok++;
  else run.wrong.set(it.d.id, it.d);
  noteAns(ok, performance.now() - it.t0);
  window.mmFeedback && mmFeedback(ok);
  afterChange();
  studied();
  $('flip')?.classList.remove('checking');
  $('flip')?.classList.add('on');
  $('fcAct').innerHTML = cardAct(it);
  $('fcNext')?.focus({ preventScroll: true });
  inView($('fcAct'));
}
/* in today's session a new word that was proven also gets a tone question a few items later */
function cardFollow(it, ok) {
  if (!ok) {
    again(it, { k: 'card', d: it.d });
    return;
  }
  if (run.mode === 'session' && it.fresh && !it.followed) {
    it.followed = true;
    run.items.splice(Math.min(run.items.length, run.i + 5), 0, { k: 'q', d: it.d, q: 's' });
  }
}
function cardDont(it) {
  LM.answer(it.d, { q: 'cn', ok: false, ms: performance.now() - it.t0 });
  it.res = 'no';
  cardShow(it, false);
  cardFollow(it, false);
}
function cardKnow(it) {
  it.claimMs = performance.now() - it.t0;
  if (Math.random() < LM.checkP(it.d)) {
    const q = LM.checkType(it.d, it.heard);
    it.chk = Object.assign({ q }, LM.question(it.d, q));
    it.st = 'check';
    $('flip').classList.add('checking');
    $('fcAct').innerHTML = cardAct(it);
    $('fcAct').querySelector('[data-c]')?.focus({ preventScroll: true });
    inView($('fcAct'));
    return;
  }
  LM.answer(it.d, { q: 'cu', ok: true, ms: it.claimMs, claim: true, unchecked: true });
  it.res = 'trust';
  cardShow(it, true);
  cardFollow(it, true);
}
function cardCheck(it, i) {
  const c = it.chk,
    ok = i === c.ans,
    x = !ok && c.q === 'cm' ? c.opts[i].id : 0;
  c.pick = i;
  LM.answer(it.d, { q: c.q, ok, ms: it.claimMs, x, claim: true, over: !ok });
  if (!ok) {
    run.over++;
    if (x) run.conf.push([it.d.id, x]);
  }
  it.res = ok ? 'ok' : 'over';
  cardShow(it, ok);
  cardFollow(it, ok);
}
/* "I was wrong" after an unchecked claim: the claim is taken back and counted as not known (no extra penalty) */
function cardOops(it) {
  LM.undo();
  LM.answer(it.d, { q: 'cn', ok: false, ms: it.claimMs });
  run.ok--;
  run.wrong.set(it.d.id, it.d);
  it.res = 'no';
  if (sit.ans.length) sit.ans[sit.ans.length - 1][0] = 0;
  $('fcAct').innerHTML = cardAct(it);
  $('fcNext')?.focus({ preventScroll: true });
  cardFollow(it, false);
}
