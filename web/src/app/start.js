/* ---------- start on Home ---------- */
document.body.dataset.level = state.level;
$('seal').textContent = NUM[state.level - 1];
applyStatic();
saveStats();
document.body.dataset.screen = 'home';
go('home');
syncRest();
/* back after two or more days off: how much is still remembered (once a day) */
{
  const s = LM.sinceLast(),
    day = new Date().toDateString();
  if (s && s.gap >= 2 && s.recall !== null && note.back !== day) {
    note.back = day;
    saveNote();
    setTimeout(() => toast(L10.backMsg(s.gap, s.recall), 6500), 900);
  }
}
/* first start: ask for a goal once (can be skipped); later, fit the memory model to this learner when enough answers exist */
if (!LM.goal && !ls.get('xc_onb', 0))
  setTimeout(() => {
    if (state.screen === 'home' && goalSheet.hidden && bkSheet.hidden && infoSheet.hidden) openGoal(true);
  }, 500);
setTimeout(() => LM.maybeOptimize(), 6000);
