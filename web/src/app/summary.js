/* ---- end of a run ---- */
/* notes under the summary: how the answers went after a break, the gain of repeating now vs tomorrow, and a late-night note */
function sumNotes() {
  const out = [];
  if (run.exam || !run.tot) return out;
  if (sit.brk && !sit.brk.told && sit.ans.length - sit.brk.at >= 5) {
    const a = sit.ans.slice(sit.brk.at);
    sit.brk.told = true;
    out.push(
      L10.brAfter(
        a.reduce((x, y) => x + y[0], 0),
        a.length,
        sit.brk.acc,
      ),
    );
  }
  const P = LM.plan();
  if ((run.mode === 'session' && sessionExtra) || (run.mode !== 'session' && P.todayLeft === 0)) {
    const g = LM.gainList([...run.before.keys()].map(id => IDX.get(id)));
    if (g.n >= 5 && g.later > g.now * 1.5) {
      const f = x => (x / g.n).toLocaleString(L10.loc, { maximumFractionDigits: 1 });
      out.push(L10.capNote(g.n, f(g.now), f(g.later)));
    }
  }
  if (lateNow() && note.night !== nightKey()) {
    note.night = nightKey();
    saveNote();
    out.push(L10.nightNote);
  }
  return out;
}
function renderSummary() {
  if (run.timer) {
    clearInterval(run.timer);
    run.timer = 0;
  }
  if (!run.closed) {
    run.closed = true;
    LM.updWeak();
    run.notes = sumNotes();
  }
  const n = run.tot,
    ok = run.ok,
    pct = n ? Math.round((ok / n) * 100) : 0;
  const up = [...run.before].filter(([id, b]) => lvl(IDX.get(id)) > Math.max(b, 0)).length,
    wrong = [...run.wrong.values()];
  const seen = new Set(),
    pairs = run.conf
      .filter(([a, b]) => {
        const k = a < b ? a + b : b + a;
        if (seen.has(k)) return false;
        seen.add(k);
        return true;
      })
      .slice(0, 3);
  const kind = run.exam ? 'exam' : run.mode;
  let note = '';
  if (run.exam) {
    const est = Math.max(0, Math.round(((ok / run.items.length - 0.25) / 0.75) * 100));
    note =
      `<p class="sumnote">${L10.examScore(pct, run.lv, est)}</p>` +
      (run.timeUp ? `<p class="sumnote">${L10.timeUp}</p>` : '');
  }
  view.innerHTML =
    (run.mode === 'quiz' ? runHead() : '') +
    `<div class="qcard sum">
    <div class="big t3">${!n ? '好' : pct >= 80 ? '好!' : '加油'}</div><h3>${L10.sumT[kind]}</h3>
    ${n ? `<div class="sumgrid"><div><b>${ok}/${n}</b><small>${L10.sumRight}</small></div><div><b>${up}</b><small>${L10.sumUp}</small></div><div><b>${wrong.length}</b><small>${L10.sumAgain}</small></div></div>` : `<p class="sumnote">${L10.sumEmpty}</p>`}
    ${note}
    ${run.over ? `<p class="sumnote">${L10.sumOver(run.over)}</p>` : ''}
    ${(run.notes || []).map(x => `<p class="sumnote rnote">${x}</p>`).join('')}
    ${pairs.length ? `<div class="sumrow"><span>${L10.sumConf}</span>${pairs.map(([a, b]) => `<span class="pair"><b>${esc(IDX.get(a).h)}</b>↔<b>${esc(IDX.get(b).h)}</b></span>`).join('')}</div>` : ''}
    ${
      wrong.length
        ? `<div class="sumwords"><div class="lbl">${L10.sumWrong}</div>${wrong
            .slice(0, 12)
            .map(d => `<span class="wchip"><b>${hzH(d)}</b>${esc(M1(d))}</span>`)
            .join('')}</div>`
        : ''
    }
    <div class="sumbtns"><button class="ghost" id="sumHome">${L10.sumHome}</button><button class="next" id="sumMore">${run.mode === 'session' ? L10.sumSessionMore : L10.sumMore}</button></div></div>`;
}

view.addEventListener('click', e => {
  if (!['card', 'quiz', 'session'].includes(state.screen) || !run) return;
  if (e.target.closest('#qTypeBtn')) {
    qMenu(!qMenuOpen());
    return;
  }
  const qt = e.target.closest('.qtrow');
  if (qt) {
    qMenu(false);
    if (qt.dataset.qt !== qType) {
      qType = qt.dataset.qt;
      saveUI();
      resetRun();
    }
    renderRun();
    $('qTypeBtn')?.focus();
    return;
  }
  const id = e.target.closest('[id]')?.id;
  if (id === 'sumHome') {
    go('home');
    return;
  }
  if (id === 'sumMore') {
    if (run.mode === 'session') sessionExtra = true;
    resetRun();
    renderRun();
    window.scrollTo(0, 0);
    return;
  }
  if (run.brk) {
    if (id === 'brGo') breakStart();
    else if (id === 'brSkip') breakEnd(false);
    else if (id === 'brStop') breakEnd(true);
    return;
  }
  const it = run.items[run.i];
  if (!it) return;
  if (it.k === 'card') {
    if (id === 'fcNo' && it.st === 'front') cardDont(it);
    else if (id === 'fcYes' && it.st === 'front') cardKnow(it);
    else if (id === 'fcOops' && it.res === 'trust') cardOops(it);
    else if (id === 'fcNext' && it.st === 'back') nextItem();
    else {
      const c = e.target.closest('[data-c]');
      if (c && it.st === 'check') cardCheck(it, +c.dataset.c);
    }
    return;
  }
  if (id === 'qNext') {
    nextItem();
    return;
  }
  if (id === 'qTr' && !it.done) {
    it.hint = true;
    renderQItem(it);
    return;
  }
  if (id === 'qAmb') {
    qAmbig(it);
    return;
  }
  const b = e.target.closest('.opts button');
  if (b && !it.done) qAnswer(it, +b.dataset.i);
});
const qMenuOpen = () => {
  const m = $('qTypeMenu');
  return !!m && !m.hidden;
};
function qMenu(open) {
  const m = $('qTypeMenu'),
    b = $('qTypeBtn');
  if (!m) return;
  m.hidden = !open;
  b.setAttribute('aria-expanded', open);
  if (open) (m.querySelector('[aria-selected="true"]') || m.firstElementChild).focus();
}
view.addEventListener('keydown', e => {
  if (!qMenuOpen()) return;
  const rows = [...$('qTypeMenu').querySelectorAll('.qtrow')],
    i = rows.indexOf(document.activeElement);
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    rows[(i + 1) % rows.length].focus();
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    rows[(i - 1 + rows.length) % rows.length].focus();
  } else if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    qMenu(false);
    $('qTypeBtn').focus();
  }
});
document.addEventListener('click', e => {
  if (qMenuOpen() && !e.target.closest('#qsel')) qMenu(false);
});
