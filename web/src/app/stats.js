/* ---------- stats screen ---------- */
let stLevel = 1,
  stSel = null,
  stConfirm = false,
  stHist = false;
function renderStats() {
  const arr = BY[stLevel],
    S = summary(arr);
  renderInsights();
  $('stLevels').innerHTML = LEVELS.map(
    l =>
      `<button class="lvpill" data-sl="${l}" aria-pressed="${l === stLevel}" style="--lc:var(--l${l})"><b>HSK ${l}</b><small>${pctTxt(summary(BY[l]).p)}</small></button>`,
  ).join('');
  $('stSum').innerHTML =
    `<div class="big">${pctTxt(S.p)}<small>${L10.memoWord}</small></div><div class="tot">HSK ${stLevel} · ${L10.words(fmt(S.n))} · ${L10.practiced(fmt(S.n - S.none))} · ${L10.matureN(fmt(S.mature))}</div>`;
  $('stStack').innerHTML = stackH(S);
  $('stKeys').innerHTML = [
    ['red', '0–6'],
    ['yellow', '7–13'],
    ['green', '14–20'],
    ['none', ''],
  ]
    .map(
      ([b, r]) =>
        `<div class="key"><b><i class="sd s-${b}"></i>${fmt(S[b])}</b>${L10.band[b]}${r ? ' · ' + L10.lvlWord + ' ' + r : ''}</div>`,
    )
    .join('');
  $('stScale').innerHTML =
    `<div class="scale">${Array.from({ length: MAXL }, (_, i) => `<i class="m${i + 1} mbg" title="${i + 1}"></i>`).join('')}</div>
    <div class="scalelbl"><span style="grid-column:1">1</span><span style="grid-column:7">7</span><span style="grid-column:14">14</span><span class="end">20 · ${L10.matureWord}</span></div>`;
  let g = '';
  for (let u = 1; u <= UNITS[stLevel]; u++) {
    const it = arr.filter(d => d.u === u),
      Su = summary(it);
    g += `<div class="ublock"><div class="ulabel">${L10.unit.toUpperCase()} ${pad(u)} <span>· ${pctTxt(Su.p)} · ${L10.matureOf(Su.mature, Su.n)}</span></div><div class="dots">${it.map(d => `<button class="${mcls(d)}" data-sid="${esc(d.id)}" aria-current="${d.id === stSel}" aria-label="${esc(d.h)} · ${esc(stTxt(d))}" title="${esc(d.h)}"></button>`).join('')}</div></div>`;
  }
  $('stGrid').innerHTML = g;
  renderDetail();
  renderFoot();
  if (window.mmStatsRendered) window.mmStatsRendered();
}
function renderDetail() {
  const el = $('stDetail'),
    d = stSel && IDX.get(stSel);
  if (!d || d.l !== stLevel) {
    el.innerHTML = `<span class="hint">${L10.dotHint}</span>`;
    return;
  }
  const e = LM.mem(d.id),
    names = [L10.skM, L10.skF, L10.skS];
  const sk = e
    ? ['m', 'f', 's']
        .map((k, i) => {
          const L = LM.skLevel(e[k]);
          return `<span class="skc">${names[i]} <i class="sd ${L < 0 ? 's-none' : `m${L} mbg`}"></i><b>${L < 0 ? '–' : L}</b></span>`;
        })
        .join('')
    : '';
  el.innerHTML = `<div class="w"><span class="no">${String(d.n).padStart(4, '0')}</span><span class="hz">${hzH(d)}</span><span class="py">${pyH(d)}</span><span style="font-size:13px">${esc(M1(d))}</span><span style="flex-basis:100%">${stH(d)}</span></div>
    ${e ? `<div class="skl">${sk}<span class="skc">${L10.detNext(L10.rel(Math.ceil(LM.nextDue(d.id))))}</span>${e.L === 1 ? `<span class="badge">${L10.detLegacy}</span>` : ''}</div>` : ''}`;
}
function renderFoot() {
  $('stFoot').innerHTML = stConfirm
    ? `<div class="confirm">${L10.rsQ(stLevel)}<button class="ghost" id="rsNo">${L10.cancel}</button><button class="danger solid" id="rsYes">${L10.rsYes}</button></div>`
    : stHist
      ? `<div class="confirm">${L10.histQ}<button class="ghost" id="hxNo">${L10.cancel}</button><button class="danger solid" id="hxYes">${L10.histYes}</button></div>`
      : `<p>${L10.rsNote}</p><div class="stbtns"><button class="danger" id="rsAsk">${L10.rsAsk(stLevel)}</button><button class="ghost" id="hxAsk">${L10.histDel}</button></div>`;
}
/* learning insights: everything comes from the answer log on this phone */
function renderInsights() {
  const I = LM.insights(),
    el = $('stIns'),
    TN = TNAME();
  if (!I.total) {
    el.innerHTML = `<div class="ihd"><b>${L10.insT}</b><small>${L10.insPriv}</small></div><p class="insnote">${L10.insEmpty}</p>`;
    return;
  }
  const col = p => (p >= 85 ? 's-green' : p >= 65 ? 's-yellow' : 's-red');
  const sk = ['m', 'f', 's', 'l', 'c']
    .filter(k => I.skills[k])
    .map(
      k =>
        `<div class="skrow${I.weak === k ? ' weak' : ''}"><span>${TN[k]}</span><span class="mbar"><span class="stack"><i style="width:${I.skills[k].p}%;background:var(--${col(I.skills[k].p)})"></i></span></span><b>${I.skills[k].p}%</b></div>`,
    )
    .join('');
  el.innerHTML = `<div class="ihd"><b>${L10.insT}</b><small>${L10.insPriv}</small></div>
    <div class="kpis"><div><b>${I.recall === null ? '–' : I.recall + '%'}</b><small>${L10.insRecall}</small></div><div><b>${fmt(I.n7)}</b><small>${L10.insAns7}</small></div><div><b>${I.cal.n >= 5 ? Math.round(I.cal.acc * 100) + '%' : '–'}</b><small>${L10.insCal}</small></div></div>
    ${sk ? `<div class="skills">${sk}</div>` : ''}
    ${I.weak ? `<p class="insnote">${L10.insWeak(TN[I.weak])}</p>` : ''}
    ${I.pairs.length ? `<div class="pairs"><span>${L10.insConf}</span>${I.pairs.map(([a, b, n]) => `<span class="pair"><b>${esc(a.h)}</b>↔<b>${esc(b.h)}</b><small>×${n}</small></span>`).join('')}</div>` : ''}
    <p class="insnote">${I.model ? L10.insModelOwn(fmt(I.model.n)) : L10.insModelBase(fmt(I.spaced), fmt(I.need))}</p>`;
}
scrStats.addEventListener('click', e => {
  const lb = e.target.closest('[data-sl]');
  if (lb) {
    stLevel = +lb.dataset.sl;
    stSel = null;
    stConfirm = false;
    renderStats();
    return;
  }
  const dot = e.target.closest('[data-sid]');
  if (dot) {
    stSel = dot.dataset.sid;
    scrStats.querySelectorAll('.dots [aria-current="true"]').forEach(x => x.setAttribute('aria-current', 'false'));
    dot.setAttribute('aria-current', 'true');
    renderDetail();
    return;
  }
  if (e.target.id === 'rsAsk') {
    stConfirm = true;
    renderFoot();
    $('rsNo').focus();
    return;
  }
  if (e.target.id === 'rsNo') {
    stConfirm = false;
    renderFoot();
    return;
  }
  if (e.target.id === 'hxAsk') {
    stHist = true;
    renderFoot();
    $('hxNo').focus();
    return;
  }
  if (e.target.id === 'hxNo') {
    stHist = false;
    renderFoot();
    return;
  }
  if (e.target.id === 'hxYes') {
    LM.clearLog();
    stHist = false;
    renderStats();
    toast(L10.histDone);
    return;
  }
  if (e.target.id === 'rsYes') {
    BY[stLevel].forEach(d => {
      delete stats[d.id];
      LM.forget(d.id);
    });
    saveStats();
    stConfirm = false;
    stSel = null;
    if (state.level === stLevel) {
      startCards();
      startQuiz();
    }
    afterChange();
    toast(L10.rsDone(stLevel));
  }
});
