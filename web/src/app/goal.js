/* ---------- goal sheet: target (level + date, HSK exam, or none) and daily amount (minutes, new words, or automatic) ---------- */
const goalSheet = $('goalSheet');
let gDraft = null,
  gRem = null,
  gRest = [],
  gOpener = null,
  gFirst = false;
const MIN_CHIPS = [5, 10, 15, 20, 30, 45, 60],
  NEW_CHIPS = [3, 5, 10, 15, 20, 30];
function openGoal(first, minLv, focus) {
  gOpener = document.activeElement;
  gFirst = !!first;
  const g = LM.goal;
  gRest = LM.rest.slice();
  gDraft = g
    ? JSON.parse(JSON.stringify(g))
    : { t: 'level', lv: LM.curLevel(), date: LM.isoDay(LM.dayAfter(90)), pace: 'auto', n: 15 };
  if (!gDraft.lv) gDraft.lv = LM.curLevel();
  if (minLv && gDraft.t !== 'none' && gDraft.lv < minLv)
    gDraft.lv = minLv; /* after the placement test: a goal at least at the new level */
  gRem = Object.assign({}, rem);
  if (first && canRemind() && !ls.get('xc_rem', null)) gRem.on = true;
  /* first start: daily reminder suggested */ if (!gDraft.date) gDraft.date = LM.isoDay(LM.dayAfter(90));
  if (!gDraft.n) gDraft.n = gDraft.pace === 'new' ? 10 : 15;
  renderGoal();
  goalSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  goalSheet.querySelector('.xbtn').focus();
  if (focus === 'rest') requestAnimationFrame(() => $('gMed')?.scrollIntoView({ block: 'center' }));
}
function closeGoal() {
  goalSheet.hidden = true;
  document.body.style.overflow = '';
  ls.set('xc_onb', 1);
  gOpener?.focus?.();
}
function renderGoal() {
  const g = gDraft,
    P = LM.plan(g),
    tgt = g.t !== 'none',
    bad = tgt && LM.daysTo(g.date) < 1;
  const seg = (k, v, label, extra) =>
    `<button class="gseg" data-g="${k}" data-v="${v}" aria-pressed="${String(g[k]) === String(v)}"${extra || ''}>${label}</button>`;
  const chips = g.pace === 'min' ? MIN_CHIPS : NEW_CHIPS,
    list = chips.includes(g.n) ? chips : chips.concat(g.n).sort((a, b) => a - b);
  let fc,
    cls = '',
    fix = '';
  if (bad) {
    fc = L10.gDateBad;
    cls = 'bad';
  } else if (P.status === 'free') fc = L10.fcFree(P.newPerDay, P.minutes);
  else if (P.status === 'review') fc = L10.fcAllDone;
  else if (P.status === 'examweek') fc = L10.stExamWeek;
  else if (P.status === 'ok') {
    fc = L10.fcOk(P.newPerDay, P.revPerDay, P.minutes, P.finish ? dateS(P.finish) : '–');
    cls = 'good';
  } else {
    fc = L10.fcBehind(P.finish ? dateS(P.finish) : null);
    cls = 'bad';
    const fx = [];
    if (g.pace !== 'new' && P.needMin)
      fx.push(`<button class="ghost" data-fix="min" data-n="${P.needMin}">${L10.fcFixMin(P.needMin)}</button>`);
    if (g.pace !== 'min' && P.need <= 60)
      fx.push(`<button class="ghost" data-fix="new" data-n="${P.need}">${L10.fcFixNew(P.need)}</button>`);
    if (P.fixDate)
      fx.push(
        `<button class="ghost" data-fix="date" data-d="${LM.isoDay(P.fixDate)}">${L10.fcFixDate(dateS(P.fixDate))}</button>`,
      );
    fix = fx.length ? `<div class="gfix">${fx.join('')}</div>` : '';
  }
  const remH = !canRemind()
    ? ''
    : `<div class="gsec"><div class="glbl">${L10.remT}</div>
      <div class="remrow"><button class="gseg" data-rem="1" aria-pressed="${!!gRem.on}">${L10.remOn}</button><button class="gseg" data-rem="0" aria-pressed="${!gRem.on}">${L10.remOff}</button>
      <input type="time" class="gdate gtime" id="gTime" value="${hhmm(gRem)}" aria-label="${L10.remT}"${gRem.on ? '' : ' disabled'}></div>
      <p class="gnote">${L10.remNote}${rem.on && gRem.on && !notifOK() ? ` <button class="linkbtn" id="gNotifSet">${L10.remOpen}</button>` : ''}</p></div>`;
  const medH = `<div class="gsec" id="gMed"><div class="glbl">${L10.medT}</div><div class="gsegs wk">${WK.map(w => `<button class="gseg" data-wk="${w}" aria-pressed="${gRest.includes(w)}" aria-label="${esc(wkName(w, 'long'))}">${esc(wkName(w, 'short'))}</button>`).join('')}</div><p class="gnote">${L10.medNote}</p></div>`;
  $('gBody').innerHTML =
    `${gFirst && !LM.level && LM.canTest() ? `<button class="ptsug" id="gPt">${L10.ptSuggest}</button>` : ''}
    <div class="gsec"><div class="glbl">${L10.gWhat}</div><div class="gsegs">${seg('t', 'level', L10.gLevel)}${seg('t', 'exam', L10.gExam)}${seg('t', 'none', L10.gNone)}</div></div>
    ${
      tgt
        ? `<div class="gsec"><div class="glbl">${L10.gLv}</div><div class="gsegs lv">${LEVELS.map(l => seg('lv', l, 'HSK ' + l, ` style="--lc:var(--l${l})"`)).join('')}</div></div>
    <div class="gsec"><label class="glbl" for="gDate">${g.t === 'exam' ? L10.gDateExam : L10.gDate}</label><input type="date" class="gdate" id="gDate" value="${g.date}" min="${LM.isoDay(LM.dayAfter(1))}"></div>`
        : ''
    }
    <div class="gsec"><div class="glbl">${L10.gPace}</div><div class="gsegs">${seg('pace', 'min', L10.gMin)}${seg('pace', 'new', L10.gNew)}${tgt ? seg('pace', 'auto', L10.gAuto) : ''}</div>
      ${g.pace !== 'auto' ? `<div class="gchips">${list.map(n => `<button class="gnum" data-n="${n}" aria-pressed="${g.n === n}">${g.pace === 'min' ? L10.gMinN(n) : L10.gNewN(n)}</button>`).join('')}</div>` : ''}</div>
    <div class="gfc ${cls}" role="status">${fc}${fix}</div>
    ${remH}
    ${medH}
    <div class="bkrow"><button class="ghost" id="gCancel">${gFirst ? L10.gSkip : L10.cancel}</button><button class="ghost pri" id="gSave"${bad ? ' disabled' : ''}>${L10.gSave}</button></div>`;
}
goalSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]') || e.target.id === 'gCancel') {
    closeGoal();
    return;
  }
  if (e.target.id === 'gPt') {
    closeGoal();
    go('placement');
    return;
  }
  if (e.target.id === 'gNotifSet') {
    try {
      MMAndroid.openNotifSettings();
    } catch (_) {}
    return;
  }
  const rb = e.target.closest('[data-rem]');
  if (rb) {
    gRem.on = rb.dataset.rem === '1';
    renderGoal();
    return;
  }
  const wk = e.target.closest('[data-wk]');
  if (wk) {
    const w = +wk.dataset.wk,
      i = gRest.indexOf(w);
    if (i >= 0) gRest.splice(i, 1);
    else {
      gRest.push(w);
      if (gRest.length > 2) gRest.shift();
    }
    renderGoal();
    return;
  }
  const g = gDraft,
    s = e.target.closest('[data-g]');
  if (s) {
    const k = s.dataset.g;
    g[k] = k === 'lv' ? +s.dataset.v : s.dataset.v;
    if (k === 't' && g.t === 'none' && g.pace === 'auto') {
      g.pace = 'new';
      g.n = 10;
    }
    if (k === 'pace' && g.pace !== 'auto')
      g.n = g.pace === 'min' ? (MIN_CHIPS.includes(g.n) ? g.n : 15) : NEW_CHIPS.includes(g.n) ? g.n : 10;
    renderGoal();
    return;
  }
  const f = e.target.closest('[data-fix]');
  if (f) {
    if (f.dataset.fix === 'date') g.date = f.dataset.d;
    else {
      g.pace = f.dataset.fix;
      g.n = +f.dataset.n;
    }
    renderGoal();
    return;
  }
  const n = e.target.closest('.gnum');
  if (n) {
    g.n = +n.dataset.n;
    renderGoal();
    return;
  }
  if (e.target.id === 'gSave') {
    const r = gRem,
      done = () => {
        rem = r;
        ls.set('xc_rem', rem);
        LM.setGoal(g);
        LM.setRest(gRest);
        syncRest();
        closeGoal();
        resetRun();
        if (state.screen === 'home') renderHome();
        else {
          syncReminder();
          if (state.screen === 'soul') renderSoul();
        }
      };
    if (r.on && canRemind() && !notifOK())
      askNotif(ok => {
        if (!ok) {
          r.on = false;
          toast(L10.remDenied);
        } else toast(L10.gSaved);
        done();
      });
    else {
      done();
      toast(L10.gSaved);
    }
  }
});
goalSheet.addEventListener('change', e => {
  if (e.target.id === 'gDate' && e.target.value) {
    gDraft.date = e.target.value;
    renderGoal();
  }
  if (e.target.id === 'gTime' && /^\d\d:\d\d/.test(e.target.value)) {
    const [h, m] = e.target.value.split(':').map(Number);
    gRem.h = h;
    gRem.m = m;
  }
});
goalSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeGoal();
  }
});
