/* ---------- Settings (v1.14, Josh): everything that left the header and Home lives here ----------
   Appearance (theme, visual effects), study language, goal/meditation/reminder, backup, research code, help & about.
   Visual effects: 'auto' (default: matched to this phone), 'low' (lighter glass, no extra effects) or 'full'. */
const setSheet = $('setSheet'),
  strkSheet = $('strkSheet');
let setOpener = null;
const FX = ['auto', 'low', 'full'];
let fxPref = FX.includes(ls.get('xc_fx', 'auto')) ? ls.get('xc_fx', 'auto') : 'auto';
/* a phone counts as slow when it says so (data saver, reduced transparency, little memory, few cores) or when the
   frame watcher (glass.js) saw it drop frames on this phone before */
function fxDetect() {
  try {
    const n = navigator,
      mq = q => matchMedia(q).matches;
    if (ls.get('xc_fxd', 0)) return 'low';
    if ((n.connection && n.connection.saveData) || mq('(prefers-reduced-transparency: reduce)')) return 'low';
    if ((n.deviceMemory && n.deviceMemory <= 3) || (n.hardwareConcurrency && n.hardwareConcurrency <= 4)) return 'low';
  } catch (e) {}
  return 'full';
}
const fxNow = () => (fxPref === 'auto' ? fxDetect() : fxPref);
function applyFx() {
  const r = document.documentElement,
    m = fxNow();
  r.classList.toggle('fx-low', m === 'low');
  r.classList.toggle('fx-full', m === 'full');
}
applyFx();
function renderFx() {
  $('fxSeg').innerHTML = FX.map(
    m => `<button role="radio" data-fx="${m}" aria-checked="${m === fxPref}">${esc(L10.fxM[m])}</button>`,
  ).join('');
  $('fxNote').textContent = L10.fxNote(fxPref, fxDetect());
}
$('fxSeg').onclick = e => {
  const b = e.target.closest('[data-fx]');
  if (!b || b.dataset.fx === fxPref) return;
  fxPref = b.dataset.fx;
  ls.set('xc_fx', fxPref);
  if (fxPref === 'full') ls.remove('xc_fxd'); /* choosing full again forgets an earlier automatic step down */
  applyFx();
  renderFx();
  requestAnimationFrame(fluidShape);
};
function renderSettings() {
  themeLabels();
  renderFx();
  $('setGoalV').textContent = goalChip();
  bkLastLine();
  $('setBkV').textContent = $('bkLast').textContent;
}
function openSettings() {
  renderSettings();
  setOpener = document.activeElement;
  setSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  setSheet.querySelector('.xbtn').focus();
}
function closeSettings(refocus = true) {
  if (!langMenu.hidden) closeLang(false);
  setSheet.hidden = true;
  document.body.style.overflow = '';
  if (refocus) setOpener?.focus?.();
}
$('setBtn').onclick = openSettings;
setSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]')) closeSettings();
});
setSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape' && langMenu.hidden) {
    e.preventDefault();
    e.stopPropagation();
    closeSettings();
  }
});
/* rows that open another sheet or screen close Settings first, so sheets never stack */
const fromSettings = fn => () => {
  closeSettings(false);
  fn();
};
$('setGoal').onclick = fromSettings(() => openGoal(false));
$('bkBtn').onclick = fromSettings(openBackup);
$('toneInfo').onclick = fromSettings(() => openInfo());
$('setRes').onclick = fromSettings(() => {
  rsOpen = true;
  go('stats');
  setTimeout(() => $('resq')?.scrollIntoView({ block: 'start', behavior: 'smooth' }), 360);
});
$('realmQ').onclick = () => openInfo('realm');

/* ---------- cultivation days: the last five weeks, which days counted and why ---------- */
function bestRun(S) {
  /* the same rules as LM.streak: practice counts, a meditation weekday and one free day a week keep the run */
  const all = [...S].sort((a, b) => a - b);
  if (!all.length) return 0;
  let best = 0;
  for (let i = 0; i < all.length; i++) {
    if (i && S.has(all[i] - 1)) continue;
    let d = all[i],
      n = 0,
      grace = -99;
    const end = LM.today();
    for (; d <= end; d++) {
      if (S.has(d) || LM.isRest(d)) n++;
      else if (grace === -99 || d - grace >= 7) {
        grace = d;
        n++;
      } else break;
    }
    while (n > 0 && !S.has(d - 1) && d - 1 >= all[i]) {
      d--;
      n--;
    }
    best = Math.max(best, n);
  }
  return best;
}
function renderStreakSheet() {
  const s = LM.streak(),
    S = LM.studyDays(),
    t = LM.today(),
    wd = LM.dayDate(t).getDay(),
    start = t - wd - 28;
  $('strkTitle').textContent = L10.strkT;
  let cells = '';
  for (let d = start; d <= t - wd + 6; d++) {
    const dt = LM.dayDate(d),
      cls = d > t ? 'fut' : S.has(d) ? 'done' : LM.isRest(d) ? 'rest' : '';
    cells += `<span class="sc ${cls}${d === t ? ' now' : ''}" aria-hidden="true">${dt.getDate()}</span>`;
  }
  $('strkBody').innerHTML =
    `<div class="sbig"><span class="inc${s.today ? ' lit' : ''}" aria-hidden="true">${$('streakBtn').querySelector('.inc').innerHTML}</span><b>${fmt(s.days)}</b><span>${esc(L10.streakU(s.days))}</span></div>
    <p class="snow ${s.today ? 'ok' : ''}">${esc(s.today ? L10.strkToday : L10.strkNot)}</p>
    <div class="scal" role="img" aria-label="${esc(L10.strkT)}">${L10.strkWd.map(w => `<span class="sw" aria-hidden="true">${esc(w)}</span>`).join('')}${cells}</div>
    <div class="skeys"><span><i class="sc done"></i>${esc(L10.strkKey[0])}</span><span><i class="sc rest"></i>${esc(L10.strkKey[1])}</span><span><i class="sc now"></i>${esc(L10.strkKey[3])}</span></div>
    <p class="ilead">${esc(L10.strkLead)}</p><p class="sbest">${esc(L10.strkBest(fmt(Math.max(bestRun(S), s.days))))}</p>`;
}
let strkOpener = null;
function openStreak() {
  renderStreakSheet();
  strkOpener = document.activeElement;
  strkSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  strkSheet.querySelector('.xbtn').focus();
}
function closeStreak() {
  strkSheet.hidden = true;
  document.body.style.overflow = '';
  strkOpener?.focus?.();
}
$('streakBtn').onclick = openStreak;
strkSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]')) closeStreak();
});
strkSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeStreak();
  }
});

/* ---------- a short tour (first start, or Settings › Short tour): three steps, can be skipped ----------
   The first one ends in the goal sheet, as the first start did before v1.14. */
const tourSheet = $('tourSheet');
let tourI = 0,
  tourFirst = false;
function renderTour() {
  const S = L10.tour,
    [t, x] = S[tourI],
    last = tourI === S.length - 1;
  $('tourBody').innerHTML =
    `<div class="tdots" aria-hidden="true">${S.map((_, i) => `<i class="${i === tourI ? 'on' : ''}"></i>`).join('')}</div>
    <div class="tart" aria-hidden="true">${['<b lang="zh-CN">金丹</b>', PLAY, '<b>HSK</b>'][tourI]}</div>
    <h2 id="tourTitle">${esc(t)}</h2><p class="ilead">${x}</p>
    <div class="trow"><button class="ghost" id="tourSkip">${esc(last && tourFirst ? L10.tourLater : L10.tourSkip)}</button><button class="planbtn" id="tourNext">${esc(last ? (tourFirst ? L10.tourGoal : L10.tourDone) : L10.tourNext)}</button></div>`;
  $('tourNext').focus();
}
function openTour(first) {
  tourFirst = !!first;
  tourI = 0;
  renderTour();
  tourSheet.hidden = false;
  document.body.style.overflow = 'hidden';
}
function closeTour(toGoal) {
  tourSheet.hidden = true;
  document.body.style.overflow = '';
  if (tourFirst) {
    ls.set('xc_onb', 1);
    if (toGoal) openGoal(true);
  }
}
tourSheet.addEventListener('click', e => {
  if (e.target.id === 'tourSkip') closeTour(false);
  else if (e.target.id === 'tourNext') {
    if (tourI < L10.tour.length - 1) {
      tourI++;
      renderTour();
    } else closeTour(true);
  }
});
tourSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeTour(false);
  }
});
$('setTour').onclick = fromSettings(() => openTour(false));
