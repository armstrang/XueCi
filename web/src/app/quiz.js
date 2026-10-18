/* ---- questions ---- */
/* o: {tr: show the translation, hint: offer "Show translation"} — sentence gaps hide the translation until answered */
function qPrompt(d, T, o) {
  return T === 'm'
    ? `<div class="q">${L10.qMean}</div><div class="big">${hzH(d)}</div>`
    : T === 'f'
      ? `<div class="q">${L10.qHz}</div><div style="font-size:22px;font-weight:800">${esc(M1(d))}</div><div class="id">${esc(M(d).split(';').slice(1).join(';'))}</div>`
      : T === 's'
        ? `<div class="q">${L10.qTone}</div><div class="big">${esc(d.h)}</div><div class="id">${esc(M1(d))}</div>`
        : T === 'l'
          ? `<div class="q">${L10.qListen}</div><button class="spk xl" id="qSay" data-say="${esc(d.h)}" aria-label="${esc(L10.replay)}" title="${esc(L10.replay)}">${SPK}</button>`
          : `<div class="q">${L10.qCloze}</div><div class="zh" style="font-size:20px">${esc(d.z).replace(esc(d.h), '<mark>＿＿</mark>')}</div>${d.l <= 3 && d.zp ? `<div class="zp">${esc(d.zp).replace(/\{[^}]*\}/, '＿＿')}</div>` : ''}${o && o.tr ? `<div class="id">${esc(TR(d))}</div>` : o && o.hint ? `<button class="linkbtn trbtn" id="qTr">${L10.showTr}</button>` : ''}`;
}
const qLab = (o, T) =>
  T === 'm' ? esc(M1(o)) : T === 's' ? `<span class="pyo">${pyOpt(o)}</span>` : `<span class="hzo">${esc(o.h)}</span>`;
function renderQItem(it) {
  const d = it.d,
    T = it.q;
  if (!it.opts) {
    Object.assign(it, LM.question(d, T));
    it.t0 = performance.now();
  }
  const ans = it.done && !run.exam,
    ok = it.ok,
    prompt = qPrompt(d, T, { tr: it.hint && !ans, hint: !run.exam && !it.done }),
    lab = o => qLab(o, T);
  const cls = i => (!ans ? '' : i === it.ans ? ' class="ok"' : i === it.pick ? ' class="ng"' : '');
  const picked = ans && !ok && T !== 's' ? it.opts[it.pick] : null;
  const amb = T === 'c' && ans && !ok && picked && !it.amb && ambLeft() > 0;
  const fb = !ans
    ? ''
    : `${it.amb ? `<div class="fbv amb">${L10.ambDone}</div>` : `<div class="fbv ${ok ? 'good' : 'bad'}">${ok ? L10.ok : L10.ng}</div>`}
    ${picked ? `<div class="picked">${L10.picked} <b class="hzs">${esc(picked.h)}</b> ${esc(picked.p)} · ${esc(M1(picked))}</div>` : ''}${amb ? `<button class="linkbtn ambbtn" id="qAmb">${L10.ambBtn}</button>` : ''}
    <div class="head"><span class="hz" style="font-size:26px">${hzH(d)}</span><span class="py">${pyH(d)}</span>${spk(d.h)}</div><div class="mean">${mH(M(d))}</div>
    <div class="zh">${exH(d)}${spk(d.z, ' sm')}</div>${zpH(d)}<div class="id">${esc(TR(d))}</div><div style="margin-top:6px">${stH(d)}</div><button class="next" id="qNext">${L10.next}</button>`;
  view.innerHTML =
    runHead() +
    `<div class="qcard qt-${T}">${prompt}<div class="opts">${it.opts.map((o, i) => `<button data-i="${i}"${cls(i)} ${ans ? 'disabled' : ''}>${i + 1}. ${lab(o)}</button>`).join('')}</div><div class="feedback" id="fb">${fb}</div></div>`;
  if (T === 'l' && !it.played && ttsOK()) {
    it.played = true;
    setTimeout(() => {
      const b = $('qSay');
      if (b && state.screen === run?.mode) speak(d.h, b);
    }, 250);
  }
}
function qAnswer(it, i) {
  if (it.done) return;
  it.done = true;
  it.pick = i;
  const ok = i === it.ans;
  it.ok = ok;
  const x = !ok && it.q !== 's' ? it.opts[i].id : 0;
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
