/* ---------- screens ---------- */
const scrHome = $('scr-home'),
  scrFocus = $('scr-focus'),
  scrStats = $('scr-stats'),
  scrSoul = $('scr-soul');
let prevScreen = 'home';
/* design hooks defined by the Liquid Glass layer (glass.js): mmTransition, mmHomeRendered, mmStatsRendered, mmFeedback */
function go(s) {
  const from = state.screen,
    run = () => show(s);
  if (window.mmTransition && from !== s) window.mmTransition(run, from, s);
  else run();
}
function show(s) {
  closeMenu(false);
  closeUMenu(false);
  closeLang(false);
  if (s === 'stats') {
    if (state.screen !== 'stats') prevScreen = state.screen;
    stLevel = state.level;
    stSel = null;
    stConfirm = false;
  }
  leaveTest();
  resetRun();
  if (s === 'placement' || state.screen === 'placement') pt = null;
  if (s === 'bt' || state.screen === 'bt') bt = null;
  if (s === 'stats') stHist = false;
  state.screen = s;
  document.body.dataset.screen = s;
  scrHome.hidden = s !== 'home';
  scrFocus.hidden = !FOCUS.includes(s);
  scrStats.hidden = s !== 'stats';
  scrSoul.hidden = s !== 'soul';
  if (FOCUS.includes(s)) {
    scrFocus.dataset.mode = s;
    $('fTitle').textContent = fTitleOf(s);
    $('listTools').hidden = s !== 'list';
    $('footNote').hidden = s !== 'list';
  }
  window.scrollTo(0, 0);
  refresh();
  const h = s === 'stats' ? $('stTitle') : s === 'soul' ? $('soulTitle') : FOCUS.includes(s) ? $('fTitle') : null;
  try {
    h && h.focus({ preventScroll: true });
  } catch (e) {}
}
function back() {
  go(state.screen === 'stats' ? prevScreen : 'home');
}
$('backBtn').onclick = back;
$('stBack').onclick = back;
document.querySelector('.tiles').onclick = e => {
  const t = e.target.closest('[data-go]');
  if (t) go(t.dataset.go);
};
const hero = $('hero');
hero.onclick = () => go('stats');
hero.onkeydown = e => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault();
    go('stats');
  }
};
function refresh() {
  renderChips();
  if (state.screen === 'home') renderHome();
  else if (state.screen === 'list') renderList();
  else if (state.screen === 'card' || state.screen === 'quiz' || state.screen === 'session') renderRun();
  else if (state.screen === 'placement') renderPlacement();
  else if (state.screen === 'bt') renderBt();
  else if (state.screen === 'soul') renderSoul();
  else renderStats();
}
function afterChange() {
  renderChips();
  if (!lvMenu.hidden) renderMenu();
  if (!uMenu.hidden) renderUnitMenu();
  if (state.screen === 'stats') renderStats();
  else if (state.screen === 'home') renderHome();
}
