/* ---------- Home: today's plan, built from the goal by the learning engine ---------- */
const PLAY =
  '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5.5v13a1 1 0 0 0 1.5.86l10.6-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5z"/></svg>';
function dateS(x) {
  const d = typeof x === 'string' ? (([y, m, dd]) => new Date(y, m - 1, dd))(x.split('-').map(Number)) : x;
  return d.toLocaleDateString(
    L10.loc,
    d.getFullYear() === new Date().getFullYear()
      ? { day: 'numeric', month: 'short' }
      : { day: 'numeric', month: 'short', year: 'numeric' },
  );
}
const skName = k => ({ m: L10.skM, f: L10.skF, s: L10.skS })[k];
/* the goal in a few words (plan card chip, Settings) */
function goalChip() {
  const g = LM.goal;
  return !g
    ? L10.planSet
    : g.t === 'none'
      ? L10.gNone
      : g.t === 'exam'
        ? L10.gExamChip(g.lv, dateS(g.date))
        : L10.gLvChip(g.lv, dateS(g.date));
}
const isNewbie = () =>
  LM.realm() === 0 && !Object.keys(stats).length && !(LM.level && LM.level.pt && LM.level.pt.length);
function renderPlan() {
  const P = LM.plan(),
    el = $('plan'),
    c = LM.challenge(),
    chip = goalChip();
  let todo = P.newToday + P.revToday > 0;
  const min = Math.max(1, Math.round((P.revToday * P.sp.rev + P.newToday * P.sp.neu) / 60));
  let line = todo
    ? [
        P.revToday ? L10.planRev(fmt(P.revToday)) : '',
        P.newToday ? L10.planNew(fmt(P.newToday)) : '',
        `<span>${L10.planMin(min)}</span>`,
      ]
        .filter(Boolean)
        .join(' · ')
    : `${L10.planDone} ✓`;
  let st =
    P.status === 'free'
      ? ['none', L10.stFree(P.newPerDay)]
      : P.status === 'ok'
        ? ['green', L10.stOk(P.finish ? dateS(P.finish) : '–')]
        : P.status === 'behind'
          ? ['red', P.needMin ? L10.stBehind(P.needMin) : L10.stBehindDate(P.fixDate ? dateS(P.fixDate) : '–')]
          : P.status === 'review'
            ? ['green', L10.stReview]
            : P.status === 'examweek'
              ? ['yellow', L10.stExamWeek]
              : ['red', L10.stPast];
  if (P.rest) {
    todo = false;
    line = `<b class="medz" lang="zh-CN">闭关</b> ${L10.planRestT}`;
    st = ['none', L10.planRest];
  } /* a meditation day: no plan */
  /* a brand-new learner (no test, no practice yet): two clear ways in instead of numbers they cannot read yet */
  scrHome.classList.toggle('newbie', isNewbie());
  if (isNewbie()) {
    el.innerHTML = `<div class="ptop"><h2 id="planT">${L10.nbT}</h2><button class="gchip" id="goalBtn" aria-haspopup="dialog">${esc(chip)} ›</button></div>
      <button class="nbopt pri" id="nbZero">${PLAY}<span><b>${L10.nbZero}</b><small>${L10.nbZeroS}</small></span></button>
      <button class="nbopt" id="nbTest"><span><b>${L10.nbTest}</b><small>${L10.nbTestS}</small></span><span class="chev" aria-hidden="true">›</span></button>`;
    el.dataset.todo = '1';
    syncWidget(L10.nbZero);
    return;
  }
  syncWidget(line);
  const cc = Math.min(c.cnt, c.n),
    cl = L10.chalT + ': ' + (c.done ? L10.chalDone : `${L10.chalTxt(skName(c.k), c.n, c.a)} · ${cc}/${c.n}`);
  el.innerHTML = `<div class="ptop"><h2 id="planT">${L10.planT}</h2><button class="chalchip${c.done ? ' done' : ''}" id="chalBtn" aria-label="${esc(cl)}"><span lang="zh-CN" aria-hidden="true">试</span>${c.done ? '✓' : `${cc}/${c.n}`}</button><button class="gchip" id="goalBtn" aria-haspopup="dialog">${esc(chip)} ›</button></div>
    <div class="pmain"><div class="ptxt"><div class="pline">${line}</div><div class="pst"><i class="sd s-${st[0]}"></i><span>${st[1]}</span></div></div>
    <button class="planbtn" id="planGo" aria-label="${esc(todo ? (P.ansT ? L10.planCont : L10.planGo) : L10.planExtra)}">${PLAY}<span>${todo ? (P.ansT ? L10.planContS : L10.planGoS) : L10.planExtraS}</span></button></div>`;
  el.dataset.todo = todo ? '1' : '0';
}
$('plan').addEventListener('click', e => {
  if (e.target.closest('#goalBtn')) {
    openGoal(false);
    return;
  }
  if (e.target.closest('#chalBtn')) {
    go('soul');
    setTimeout(
      () => document.querySelector('#soulBody .chal')?.scrollIntoView({ block: 'center', behavior: 'smooth' }),
      360,
    );
    return;
  }
  if (e.target.closest('#nbTest')) {
    go('placement');
    return;
  }
  if (e.target.closest('#planGo') || e.target.closest('#nbZero')) {
    sessionExtra = $('plan').dataset.todo !== '1';
    go('session');
  }
});
