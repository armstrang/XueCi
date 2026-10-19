/* ---------- home ----------
   v1.14 (Josh): the realm sits in the middle as a glass orb that flows into the panel below it (realm text + today's
   plan), then word mastery with the HSK picker, then the practice dock. Header: wordmark, cultivation days, Settings. */
/* the HSK pills (Home and Stats): six, or nine once HSK 7–9 are open (then just the numbers, so they still fit) */
function lvPills(el, key, cur) {
  el.style.setProperty('--n', LEVELS.length);
  el.classList.toggle('n9', LEVELS.length > 6);
  el.innerHTML = LEVELS.map(
    l =>
      `<button class="lvpill" data-${key}="${l}" aria-pressed="${l === cur}" aria-label="HSK ${l}, ${L10.memoWord} ${pctTxt(summary(BY[l]).p)}" style="--lc:var(--l${l})"><b><span class="hl">HSK </span>${l}</b><small>${pctTxt(summary(BY[l]).p)}</small></button>`,
  ).join('');
}
function renderHome() {
  const L = state.level,
    S = summary(BY[L]),
    pc = pctTxt(S.p);
  lvPills($('lvPills'), 'l', L);
  $('heroPct').textContent = pc;
  $('heroLv').textContent = `HSK ${L} · ${L10.words(fmt(S.n))}`;
  /* mastery as one bar: understood, fair, weak; the rest of the track is not practised yet */
  $('heroBar').innerHTML = ['green', 'yellow', 'red']
    .map(b => `<i class="s-${b}" style="width:${((S[b] / S.n) * 100).toFixed(2)}%"></i>`)
    .join('');
  $('heroKeys').innerHTML = ['green', 'yellow', 'red', 'none']
    .map(b => `<span class="hkey"><b>${fmt(S[b])}</b><small><i class="sd s-${b}"></i>${L10.band[b]}</small></span>`)
    .join('');
  hero.textContent = L10.statsShort + ' ›';
  hero.setAttribute('aria-label', `${L10.stTitle} · HSK ${L} · ${pc}`);
  renderPlan();
  renderCurLv();
  renderStreak();
  syncReminder();
  bkDot();
  if (window.mmHomeRendered) window.mmHomeRendered(S);
  requestAnimationFrame(fluidShape);
}
$('lvPills').onclick = e => {
  const p = e.target.closest('.lvpill');
  if (p && +p.dataset.l !== state.level) setLevel(+p.dataset.l);
};

/* the fluid glass shape: a circle around the orb that flows into the rounded panel below it, with soft fillets where
   they meet (like a drop joining a pool). Drawn once per layout as one SVG path — static paint, no filters. */
function fluidShape() {
  const f = $('fluid'),
    o = $('curLvBtn');
  if (!f.offsetParent) return;
  const fr = f.getBoundingClientRect(),
    or = o.getBoundingClientRect(),
    W = fr.width,
    H = fr.height,
    cx = or.left - fr.left + or.width / 2,
    cy = or.top - fr.top + or.height / 2,
    R = or.width / 2 + 9,
    Y = Math.min(H - 60, cy + R * 0.6),
    r = Math.min(34, (H - Y) / 2),
    k = 26,
    h = Math.sqrt(Math.max(1, R * R - (Y - cy) ** 2)),
    y1 = Y - k * 0.5,
    x1 = Math.sqrt(Math.max(1, R * R - (y1 - cy) ** 2)),
    n = v => v.toFixed(1);
  const svg = $('fshape');
  svg.setAttribute('viewBox', `0 0 ${n(W)} ${n(H)}`);
  $('fpath').setAttribute(
    'd',
    `M0 ${n(Y + r)}A${n(r)} ${n(r)} 0 0 1 ${n(r)} ${n(Y)}L${n(cx - h - k)} ${n(Y)}Q${n(cx - h)} ${n(Y)} ${n(cx - x1)} ${n(y1)}` +
      `A${n(R)} ${n(R)} 0 1 1 ${n(cx + x1)} ${n(y1)}Q${n(cx + h)} ${n(Y)} ${n(cx + h + k)} ${n(Y)}L${n(W - r)} ${n(Y)}` +
      `A${n(r)} ${n(r)} 0 0 1 ${n(W)} ${n(Y + r)}L${n(W)} ${n(H - r)}A${n(r)} ${n(r)} 0 0 1 ${n(W - r)} ${n(H)}` +
      `L${n(r)} ${n(H)}A${n(r)} ${n(r)} 0 0 1 0 ${n(H - r)}Z`,
  );
  f.style.setProperty('--fy', n(Y) + 'px');
}
try {
  new ResizeObserver(() => fluidShape()).observe($('fluid'));
} catch (e) {
  addEventListener('resize', fluidShape);
}

/* cultivation days (LM.streak): an incense stick in the header, lit once today has some practice */
function renderStreak() {
  const s = LM.streak(),
    b = $('streakBtn');
  $('streakN').textContent = fmt(s.days);
  $('streakU').textContent = L10.streakU(s.days);
  b.classList.toggle('lit', s.today);
  b.setAttribute('aria-label', L10.streakAria(fmt(s.days), s.today));
}
