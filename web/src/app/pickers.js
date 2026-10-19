/* ---------- level + unit pickers (focused screens) ---------- */
const lvbtn = $('lvbtn'),
  lvMenu = $('lvMenu'),
  lvList = $('lvList');
const ubtn = $('ubtn'),
  uMenu = $('uMenu'),
  uGrid = $('uGrid');
function renderChips() {
  const L = state.level,
    u = unit();
  $('lvName').textContent = 'HSK ' + L;
  lvbtn.setAttribute('aria-label', L10.pickLv + ': HSK ' + L);
  $('uName').textContent = u ? L10.unit + ' ' + pad(u) : L10.allShort;
  ubtn.setAttribute('aria-label', L10.pickU + ': ' + (u ? L10.unit + ' ' + u : L10.allU));
  $('allHead').innerHTML = L10.allLv(fmt(masteredAll()), fmt(DATA.length));
}
function renderMenu() {
  lvList.innerHTML = LEVELS.map(l => {
    const S = summary(BY[l]),
      tot = S.n;
    return `<button class="lvrow" role="option" data-l="${l}" aria-selected="${state.level === l}" style="--lc:var(--l${l})">
      <span class="l"><i class="sd" style="width:10px;height:10px;background:var(--l${l})"></i><span class="nm"><b>HSK ${l}</b><small>${L10.words(fmt(tot))}</small></span></span>
      <span class="r"><span class="mbar"><span class="stack">${stackH(S)}</span></span><span class="pct">${pctTxt(S.p)}</span></span></button>`;
  }).join('');
}
function openMenu() {
  closeUMenu(false);
  renderMenu();
  lvMenu.hidden = false;
  lvbtn.setAttribute('aria-expanded', 'true');
  (lvList.querySelector('[aria-selected="true"]') || lvList.firstElementChild).focus();
}
function closeMenu(focusBtn) {
  lvMenu.hidden = true;
  lvbtn.setAttribute('aria-expanded', 'false');
  if (focusBtn) lvbtn.focus();
}
lvbtn.onclick = () => (lvMenu.hidden ? openMenu() : closeMenu(false));
lvList.onclick = e => {
  const r = e.target.closest('.lvrow');
  if (!r) return;
  closeMenu(true);
  if (+r.dataset.l !== state.level) setLevel(+r.dataset.l);
};
$('openStats').onclick = () => go('stats');
lvMenu.addEventListener('keydown', e => {
  const rows = [...lvList.querySelectorAll('.lvrow'), $('openStats')],
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
    closeMenu(true);
  }
});
function unitItems(u) {
  const L = state.level;
  return u ? BY[L].filter(d => d.u === u) : BY[L];
}
function renderUnitMenu() {
  const L = state.level,
    u = unit(),
    Sa = summary(BY[L]);
  let h = `<button class="ucell uall" data-u="0" aria-current="${u === 0}"><b>${L10.allU}</b><small>${L10.words(fmt(Sa.n))} · ${pctTxt(Sa.p)} · ${L10.matureOf(fmt(Sa.mature), fmt(Sa.n))}</small><span class="mbar"><span class="stack">${stackH(Sa)}</span></span></button>`;
  for (let k = 1; k <= UNITS[L]; k++) {
    const S = summary(unitItems(k));
    h += `<button class="ucell${S.mature === S.n ? ' done' : ''}" data-u="${k}" aria-current="${u === k}" aria-label="${L10.unit} ${k}"><b>${L10.uS}${pad(k)}</b><small>${pctTxt(S.p)}</small><span class="mbar"><span class="stack">${stackH(S)}</span></span></button>`;
  }
  uGrid.innerHTML = h;
}
function openUMenu() {
  closeMenu(false);
  renderUnitMenu();
  uMenu.hidden = false;
  ubtn.setAttribute('aria-expanded', 'true');
  const cur = uGrid.querySelector('[aria-current="true"]');
  cur?.scrollIntoView({ block: 'nearest' });
  cur?.focus();
}
function closeUMenu(focusBtn) {
  uMenu.hidden = true;
  ubtn.setAttribute('aria-expanded', 'false');
  if (focusBtn) ubtn.focus();
}
ubtn.onclick = () => (uMenu.hidden ? openUMenu() : closeUMenu(false));
uGrid.onclick = e => {
  const b = e.target.closest('.ucell');
  if (!b) return;
  closeUMenu(true);
  setUnit(+b.dataset.u);
};
uMenu.addEventListener('keydown', e => {
  const cells = [...uGrid.querySelectorAll('.ucell')],
    i = cells.indexOf(document.activeElement);
  if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
    e.preventDefault();
    cells[Math.min(i + 1, cells.length - 1)].focus();
  } else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
    e.preventDefault();
    cells[Math.max(i - 1, 0)].focus();
  } else if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeUMenu(true);
  }
});
document.addEventListener('click', e => {
  if (!lvMenu.hidden && !e.target.closest('#lvbtn,#lvMenu')) closeMenu(false);
  if (!uMenu.hidden && !e.target.closest('#ubtn,#uMenu')) closeUMenu(false);
  if (!langMenu.hidden && !e.target.closest('#langwrap')) closeLang(false);
});
function setLevel(l) {
  state.level = l;
  state.shown = 60;
  state.q = '';
  $('q').value = '';
  saveUI();
  document.body.dataset.level = l;
  startCards();
  startQuiz();
  refresh();
}
function setUnit(u) {
  state.unitBy[state.level] = u;
  state.shown = 60;
  saveUI();
  startCards();
  startQuiz();
  refresh();
}
function pool() {
  const L = state.level;
  return unit() ? BY[L].filter(d => d.u === unit()) : BY[L];
}
