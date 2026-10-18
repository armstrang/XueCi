/* ---------- home ---------- */
const RING_C = 2 * Math.PI * 52;
function renderHome() {
  const L = state.level,
    S = summary(BY[L]),
    pc = pctTxt(S.p);
  $('lvPills').innerHTML = LEVELS.map(
    l =>
      `<button class="lvpill" data-l="${l}" aria-pressed="${l === L}" style="--lc:var(--l${l})"><b>HSK ${l}</b><small>${pctTxt(summary(BY[l]).p)}</small></button>`,
  ).join('');
  /* one arc per level, deepest green first, so the ring fades from mature green to young red */
  let off = 0,
    arcs = '';
  for (let s = MAXL; s >= 0; s--) {
    if (!S.lv[s]) continue;
    const len = (S.lv[s] / S.n) * RING_C;
    arcs += `<circle class="sg m${s}" cx="60" cy="60" r="52" style="stroke:var(--mc)" stroke-dasharray="${len.toFixed(2)} ${RING_C.toFixed(2)}" stroke-dashoffset="${(-off).toFixed(2)}"/>`;
    off += len;
  }
  $('ringArcs').innerHTML = arcs;
  $('heroPct').textContent = pc;
  $('heroLbl').textContent = L10.memoWord;
  $('heroLv').textContent = `HSK ${L} · ${L10.words(fmt(S.n))}`;
  $('heroKeys').innerHTML = ['green', 'yellow', 'red', 'none']
    .map(b => `<div class="hkey"><i class="sd s-${b}"></i>${L10.band[b]}<b>${fmt(S[b])}</b></div>`)
    .join('');
  $('heroCnt').innerHTML = L10.lvCount(fmt(S.mature), fmt(S.n));
  $('heroGo').textContent = L10.statsShort + ' ›';
  hero.setAttribute('aria-label', `${L10.stTitle} · HSK ${L} · ${pc}`);
  renderPlan();
  renderCurLv();
  syncReminder();
  bkDot();
  if (window.mmHomeRendered) window.mmHomeRendered(S);
}
$('lvPills').onclick = e => {
  const p = e.target.closest('.lvpill');
  if (p && +p.dataset.l !== state.level) setLevel(+p.dataset.l);
};
