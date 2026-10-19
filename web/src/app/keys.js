/* ---------- keyboard + Android back ---------- */
/* Back closes the topmost layer: a menu, then the focused screen (back to Home). false lets the app exit. */
window.mmBack = function () {
  if (window.mmBusy && mmBusy()) return true; /* a screen animation is still running */
  if (!eggOv.hidden) {
    eggHide();
    return true;
  }
  if (!gateOv.hidden) {
    gateClose();
    return true;
  }
  if (!lvlSheet.hidden) {
    closeLvl();
    return true;
  }
  if (!goalSheet.hidden) {
    closeGoal();
    return true;
  }
  if (!infoSheet.hidden) {
    closeInfo();
    return true;
  }
  if (!langMenu.hidden) {
    closeLang(true);
    return true;
  }
  if (!tourSheet.hidden) {
    closeTour(false);
    return true;
  }
  if (!setSheet.hidden) {
    closeSettings();
    return true;
  }
  if (!strkSheet.hidden) {
    closeStreak();
    return true;
  }
  if (!shareSheet.hidden) {
    closeShare();
    return true;
  }
  if (!bkSheet.hidden) {
    bkBack();
    return true;
  }
  if (qMenuOpen()) {
    qMenu(false);
    return true;
  }
  if (!langMenu.hidden) {
    closeLang(false);
    return true;
  }
  if (!lvMenu.hidden) {
    closeMenu(false);
    return true;
  }
  if (!uMenu.hidden) {
    closeUMenu(false);
    return true;
  }
  if (state.screen !== 'home') {
    back();
    return true;
  }
  return false;
};
document.addEventListener('keydown', e => {
  if (
    !lvMenu.hidden ||
    !uMenu.hidden ||
    !langMenu.hidden ||
    !infoSheet.hidden ||
    !bkSheet.hidden ||
    !goalSheet.hidden ||
    !lvlSheet.hidden ||
    !setSheet.hidden ||
    !tourSheet.hidden ||
    !strkSheet.hidden ||
    !shareSheet.hidden ||
    qMenuOpen()
  )
    return;
  if (e.key === 'Escape' && state.screen !== 'home' && !/^(INPUT|SELECT)$/.test(e.target.tagName)) {
    back();
    return;
  }
  if (/^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) return;
  if (state.screen === 'placement') {
    if (/^[1-4]$/.test(e.key)) document.querySelectorAll('#ptOpts button')[+e.key - 1]?.click();
    else if (e.key === '0' || e.key === '5') $('ptIdk')?.click();
    else if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') $('ptBegin')?.click();
    return;
  }
  if (state.screen === 'bt') {
    if (/^[1-4]$/.test(e.key)) document.querySelectorAll('#btOpts button')[+e.key - 1]?.click();
    else if (e.key === '0' || e.key === '5') $('btIdk')?.click();
    else if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') $('btBegin')?.click();
    return;
  }
  if (!run || !['card', 'quiz', 'session'].includes(state.screen)) return;
  if (run.brk) {
    if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') $('brSkip')?.click();
    return;
  }
  const it = run.items[run.i],
    pick = (sel, k) => document.querySelectorAll(sel)[+k - 1]?.click();
  if (!it) {
    if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') $('sumMore')?.click();
    return;
  }
  if (it.k === 'card') {
    if (it.st === 'front') {
      if (e.key === 'ArrowLeft') $('fcNo')?.click();
      if (e.key === 'ArrowRight') $('fcYes')?.click();
    } else if (it.st === 'check') {
      if (/^[1-4]$/.test(e.key)) pick('#fcAct [data-c]', e.key);
    } else if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') $('fcNext')?.click();
    return;
  }
  if (/^[1-4]$/.test(e.key)) pick('.opts button', e.key);
  if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') $('qNext')?.click();
});
