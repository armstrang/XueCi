/* ---- questions ---- */
/* o: {tr: show the translation, hint: offer "Show translation"} — sentence gaps hide the translation until answered */
const gapZ = d => esc(d.z).replace(esc(d.h), '<mark>＿＿</mark>');
function qPrompt(d, T, o) {
  if (T === 'p')
    /* production: the meaning (and the sentence with a gap) — the pinyin is typed from memory */
    return `<div class="q">${L10.qPy}</div><div style="font-size:22px;font-weight:800">${esc(M1(d))}</div><div class="id">${esc(M(d).split(';').slice(1).join(';'))}</div>${LM.clozeOK(d) ? `<div class="zh pyz">${gapZ(d)}</div>` : ''}`;
  if (T === 't')
    /* a whole sentence to understand: which translation is right? */
    return `<div class="q">${L10.qTrans}</div><div class="zh" style="font-size:20px">${esc(d.z)}</div>${d.l <= 3 && d.zp ? `<div class="zp">${esc(d.zp).replace(/[{}]/g, '')}</div>` : ''}`;
  return T === 'm'
    ? `<div class="q">${L10.qMean}</div><div class="big">${hzH(d)}</div>`
    : T === 'f'
      ? `<div class="q">${L10.qHz}</div><div style="font-size:22px;font-weight:800">${esc(M1(d))}</div><div class="id">${esc(M(d).split(';').slice(1).join(';'))}</div>`
      : T === 's'
        ? `<div class="q">${L10.qTone}</div><div class="big">${esc(d.h)}</div><div class="id">${esc(M1(d))}</div>`
        : T === 'l'
          ? `<div class="q">${L10.qListen}</div><button class="spk xl" id="qSay" data-say="${esc(d.h)}" aria-label="${esc(L10.replay)}" title="${esc(L10.replay)}">${SPK}</button>`
          : `<div class="q">${L10.qCloze}</div><div class="zh" style="font-size:20px">${gapZ(d)}</div>${d.l <= 3 && d.zp ? `<div class="zp">${esc(d.zp).replace(/\{[^}]*\}/, '＿＿')}</div>` : ''}${o && o.tr ? `<div class="id">${esc(TR(d))}</div>` : o && o.hint ? `<button class="linkbtn trbtn" id="qTr">${L10.showTr}</button>` : ''}`;
}
const qLab = (o, T) =>
  T === 'm'
    ? esc(M1(o))
    : T === 's'
      ? `<span class="pyo">${pyOpt(o)}</span>`
      : T === 't'
        ? `<span class="tro">${esc(TR(o))}</span>`
        : `<span class="hzo">${esc(o.h)}</span>`;
/* the typing box of a pinyin question: answered → shows what was typed */
function pyBox(it, done) {
  const v = esc(it.typed || '');
  return done
    ? `<div class="pyform"><input class="pyin ${it.ok ? 'ok' : 'ng'}" value="${v}" disabled aria-label="${esc(L10.qPy)}"></div>`
    : `<form class="pyform" id="pyForm"><input class="pyin" id="pyIn" autocomplete="off" autocapitalize="off" autocorrect="off" spellcheck="false" enterkeyhint="done" placeholder="${esc(L10.pyPh)}" aria-label="${esc(L10.qPy)}"><button class="next pygo" type="submit">${L10.pyCheck}</button></form>
      <p class="pyhelp">${L10.pyHelp}</p><button class="idkbtn" id="pyIdk">${L10.idk}</button>`;
}
function renderQItem(it) {
  const d = it.d,
    T = it.q;
  if (!it.opts && !it.typed0) {
    Object.assign(it, LM.question(d, T));
    it.typed0 = T === 'p';
    it.t0 = performance.now();
  }
  const ans = it.done && !run.exam,
    ok = it.ok,
    prompt = qPrompt(d, T, { tr: it.hint && !ans, hint: !run.exam && !it.done }),
    lab = o => qLab(o, T);
  const cls = i => (!ans ? '' : i === it.ans ? ' class="ok"' : i === it.pick ? ' class="ng"' : '');
  const picked = ans && !ok && T !== 's' && T !== 'p' && T !== 't' ? it.opts[it.pick] : null;
  const amb = T === 'c' && ans && !ok && picked && !it.amb && ambLeft() > 0;
  const fb = !ans
    ? ''
    : `${it.amb ? `<div class="fbv amb">${L10.ambDone}</div>` : `<div class="fbv ${ok ? 'good' : 'bad'}">${ok ? L10.ok : L10.ng}</div>`}${T === 'p' && !ok && it.tl ? `<div class="picked">${L10.pyToneless}</div>` : ''}${T === 'p' && ok && it.alt ? `<div class="picked">${L10.pyAlt(esc(it.alt.h))}</div>` : ''}
    ${picked ? `<div class="picked">${L10.picked} <b class="hzs">${esc(picked.h)}</b> ${esc(picked.p)} · ${esc(M1(picked))}</div>` : ''}${amb ? `<button class="linkbtn ambbtn" id="qAmb">${L10.ambBtn}</button>` : ''}
    <div class="head"><span class="hz" style="font-size:26px">${hzH(d)}</span><span class="py">${pyH(d)}</span>${spk(d.h)}</div><div class="mean">${mH(M(d))}</div>
    <div class="zh">${exH(d)}${spk(d.z, ' sm')}</div>${zpH(d)}<div class="id">${esc(TR(d))}</div><div style="margin-top:6px">${stH(d)}</div><button class="next" id="qNext">${L10.next}</button>`;
  const body =
    T === 'p'
      ? pyBox(it, it.done)
      : `<div class="opts">${it.opts.map((o, i) => `<button data-i="${i}"${cls(i)} ${ans ? 'disabled' : ''}>${i + 1}. ${lab(o)}</button>`).join('')}</div>`;
  view.innerHTML =
    runHead() + `<div class="qcard qt-${T}">${prompt}${body}<div class="feedback" id="fb">${fb}</div></div>`;
  if (T === 'p' && !it.done) setTimeout(() => $('pyIn')?.focus({ preventScroll: true }), 60);
  if (T === 'l' && !it.played && ttsOK()) {
    it.played = true;
    setTimeout(() => {
      const b = $('qSay');
      if (b && state.screen === run?.mode) speak(d.h, b);
    }, 250);
  }
}
/* a typed answer (pinyin question): checked by the engine (tones, 一/不, neutral tones, same-meaning words) */
function qTyped(it, text) {
  if (it.done) return;
  const r = text == null ? { ok: false } : LM.pyCheck(it.d, text);
  it.typed = text || '';
  it.tl = !!r.toneless;
  it.alt = r.alt || null;
  qAnswer(it, r.ok ? -2 : -3); /* −2 typed right, −3 typed wrong (a typed question has no options) */
}
function qAnswer(it, i) {
  if (it.done) return;
  it.done = true;
  it.pick = i;
  const ok = i === -2 || (i >= 0 && i === it.ans);
  it.ok = ok;
  const x = !ok && i >= 0 && it.q !== 's' && it.q !== 't' ? it.opts[i].id : 0;
  LM.answer(it.d, { q: it.q, ok, ms: performance.now() - it.t0, x, exam: run.exam, hint: !!it.hint });
  run.tot++;
  if (!run.exam) noteAns(ok, performance.now() - it.t0);
  if (ok) run.ok++;
  else {
    run.wrong.set(it.d.id, it.d);
    if (x) run.conf.push([it.d.id, x]);
    again(it, { k: 'q', d: it.d, q: it.q });
  }
  window.mmFeedback && mmFeedback(ok);
  afterChange();
  studied();
  if (run.exam) {
    run.i++;
    renderRun();
    return;
  }
  renderQItem(it);
}

/* the learner says their wrong pick also fits the sentence: the answer is taken back, and the two words are never
   offered together again (at most 3 times a day, so it can't be used to skip questions) */
const ambLeft = () => {
  const d = new Date().toDateString();
  return note.amb && note.amb.d === d ? 3 - note.amb.n : 3;
};
function qAmbig(it) {
  const d = it.d,
    p = it.opts[it.pick];
  if (!p || it.amb || it.ok) return;
  LM.undo();
  LM.markAmbiguous(d.id, p.id);
  it.amb = true;
  run.tot--;
  run.wrong.delete(d.id);
  const k = run.conf.findIndex(c => c[0] === d.id && c[1] === p.id);
  if (k >= 0) run.conf.splice(k, 1);
  const j = run.items.findIndex((x, i) => i > run.i && x.d === d && x.q === it.q && !x.opts);
  if (j > 0) {
    run.items.splice(j, 1);
    run.again.set(d.id, Math.max(0, (run.again.get(d.id) || 1) - 1));
  }
  if (sit.ans.length) sit.ans.pop();
  const day = new Date().toDateString();
  note.amb = { d: day, n: (note.amb && note.amb.d === day ? note.amb.n : 0) + 1 };
  saveNote();
  afterChange();
  renderQItem(it);
}
