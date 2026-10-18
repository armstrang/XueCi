/* ---------- realm chip (beside the language button) and the realm sheet ----------
   The realm changes only through a test: the placement test, or a breakthrough (突破) once the stage is 圆满. One test a
   week. The realm only steers the daily plan — every level stays open in List, Cards and Quiz. */
const lvlSheet = $('lvlSheet');
let lvlOpener = null;
const realmPct = r => {
  const st = LM.stage(r < 1 ? LM.baseLevel() : r);
  return st ? Math.round(Math.min(1, st.share / 0.8) * 100) : 0;
};
/* the HSK level a realm stands for: realm r studies HSK r; a finished realm shows its last level with a tick */
const realmHSK = r => (r < 1 ? '' : LM.isFinal(r) ? `HSK ${realmLv(r)} ✓` : `HSK ${r}`);
/* the chip: realm name, HSK, and a small ring that fills up to 圆满 (progress ÷ 80 %); unstable → a crack mark */
function renderCurLv() {
  const r = LM.realm(),
    b = $('curLvBtn'),
    st = LM.stage(r < 1 ? LM.baseLevel() : r),
    open = LM.btOpen() && LM.canTest(),
    unst = !LM.stability().ok,
    p = realmPct(r);
  $('curLvName').textContent = RN[r];
  $('curLvSub').textContent = r ? realmHSK(r) : L10.chipTest;
  b.style.setProperty('--lc', rc(r));
  b.style.setProperty('--p', p);
  b.classList.toggle('mortal', !r);
  b.classList.toggle('btready', open);
  b.classList.toggle('unstable', unst);
  b.setAttribute(
    'aria-label',
    `${L10.realmL}: ${RN[r]} ${RPY[r]}, ${L10.realmM[r]}${r && st ? `, ${SN[st.i]} ${L10.stageM[st.i]}` : ''}${r ? `, ${realmHSK(r)}` : ''}, ${L10.chipProg(p)}${unst ? '. ' + L10.unstT : open ? '. ' + L10.stOpen : ''}`,
  );
}
const perBars = per =>
  `<div class="lvper">${per.map((p, i) => `<div class="skrow"><span>HSK ${i + 1}</span><span class="mbar"><span class="stack"><i style="width:${p}%;background:var(--l${i + 1})"></i></span></span><b>${p}%</b></div>`).join('')}</div>`;
const realmHead = (r, big) =>
  `<div class="rhead${big ? ' lg' : ''}" style="--lc:${rc(r)}"><span class="rname" lang="zh-CN">${RN[r]}</span><span class="rpy">${RPY[r]}</span><span class="rmean">${esc(L10.realmM[r])}${r ? ` · ${realmHSK(r)}` : ''}</span></div>`;
const hd = (hz, py, t) =>
  `<h3 class="shd"><span lang="zh-CN">${hz}</span> <small class="hpy">${py}</small> <span class="hsep">·</span> ${esc(t)}</h3>`;
/* how a passed realm was reached: broken through (with the foundation's quality) or recognised by the placement test */
function realmHow(i, r) {
  if (i < 1 || i > r) return '';
  const g = LM.grades()[i];
  if (g) return `<span class="grade g${g} sm"><b lang="zh-CN">${LM.GRADES[g]}</b></span> ${esc(L10.gradeM[g])}`;
  const H = (LM.level && LM.level.hist) || [];
  const byTest = H.some(h => h[2] === 'test' && h[0] >= i) && !H.some(h => h[2] === 'bt' && h[0] === i);
  return byTest ? `<span class="recog" lang="zh-CN">认定</span> ${esc(L10.recog)}` : '';
}
/* the path of the realms: passed ones filled, the current one ringed; tap any to read its name, pinyin and meaning.
   Before the gate is open the path simply ends at 飞升: nothing hints that there is more (Josh: a real surprise). */
function rpInfo(i, r, brief) {
  const how = realmHow(i, r);
  if (brief) return `${how ? `<span class="rphow">${how}</span><br>` : ''}<small>${esc(L10.realmD[i])}</small>`;
  return `<b lang="zh-CN" style="color:${rc(i)}">${RN[i]}</b> <span class="rpy2">${RPY[i]}</span> · ${esc(L10.realmM[i])} · ${i ? realmHSK(i) || 'HSK ' + i : esc(L10.notTested)}${i === r ? ` · <em>${L10.youHere}</em>` : ''}${how ? `<br><span class="rphow">${how}</span>` : ''}<br><small>${esc(L10.realmD[i])}</small>`;
}
function pathH(r) {
  const top = TOPR(),
    nodes = RN.slice(0, top + 1).map(
      (n, i) =>
        `${i ? `<span class="rpl${i <= r ? ' done' : ''}" aria-hidden="true"></span>` : ''}<button class="rp${i < r ? ' done' : i === r ? ' cur' : ''}${LM.grades()[i] === 4 ? ' perfect' : ''}" data-rp="${i}" style="--lc:${rc(i)}" aria-pressed="${i === r}" aria-label="${n} ${RPY[i]}, ${esc(L10.realmM[i])}"><span lang="zh-CN">${RS[i]}</span></button>`,
    );
  return `<div class="rpath${top > 7 ? ' long' : ''}">${nodes.join('')}</div><p class="rpinfo" aria-live="polite">${rpInfo(r, r, true)}</p>`;
}
function rpPick(p) {
  const box = p.closest('.rpath');
  box.querySelectorAll('.rp').forEach(x => x.setAttribute('aria-pressed', String(x === p)));
  const info = box.nextElementSibling;
  if (info) info.innerHTML = rpInfo(+p.dataset.rp, LM.realm());
}
/* progress inside the realm: four stage segments (初期 <25 %, 中期 25–50 %, 后期 50–80 %, 圆满 ≥80 % of the level's words
   solid), the next step, and the engine's forecast (pace of the last 14 days) or, at 圆满, the chance to pass a breakthrough */
const TH = [0, 0.25, 0.5, 0.8, 1];
function stageH(r) {
  const L = r < 1 ? LM.baseLevel() : r,
    st = LM.stage(L);
  if (!st) return '';
  const i = st.i,
    pct = Math.round(Math.min(1, st.share / 0.8) * 100),
    fc = r >= 1 && !LM.isFinal(r) ? LM.forecast() : null;
  /* each segment: solid words in the realm colour, the placement test's half credit in a lighter shade after it */
  const sol = st.share - st.testShare,
    fill = (x, k) => (Math.max(0, Math.min(1, (x - TH[k]) / (TH[k + 1] - TH[k]))) * 100).toFixed(1);
  const segs = [0, 1, 2, 3]
    .map(
      k =>
        `<span class="sg">${st.testShare > 0 ? `<i class="tc" style="width:${fill(st.share, k)}%"></i>` : ''}<i style="width:${fill(sol, k)}%"></i></span>`,
    )
    .join('');
  const labs = SN.map(
    (n, k) => `<span class="sgl${k === i ? ' cur' : ''}"><b lang="zh-CN">${n}</b><small>${SPY[k]}</small></span>`,
  ).join('');
  let note;
  if (r < 1) note = L10.prepNote;
  else if (LM.isFinal(r)) note = r >= 10 ? L10.stTop : L10.stAll;
  else if (i === 3) {
    const p = LM.btChance();
    note = L10.stOpen + (p === null ? '' : ' ' + L10.btChance(p < 5 ? '<5' : p > 95 ? '>95' : p));
  } else note = L10.stNext(fmt(fc ? fc.next : 0), SN[i + 1]);
  const eta =
    fc && i < 3
      ? fc.dNext
        ? `<div class="steta"><b>${L10.etaL}:</b> ${L10.etaNext(dateS(LM.dayAfter(fc.dNext)))}${fc.dFull && fc.dFull > fc.dNext ? ' · ' + L10.etaFull(dateS(LM.dayAfter(fc.dFull))) : ''} · ${L10.perWeek(fmt(fc.week))}</div>`
        : `<div class="steta">${L10.etaNone}</div>`
      : '';
  return `<div class="stage" style="--lc:${rc(r < 1 ? L : r)}"><div class="sthd"><span>${r < 1 ? esc(L10.prepT(RN[L], L)) : L10.progT}</span><b>${pct}%</b></div>
    <div class="sgtrack" role="img" aria-label="${pct}%, ${SN[i]} ${esc(L10.stageM[i])}">${segs}</div><div class="sglabels" aria-hidden="true">${labs}</div>
    <div class="stl2"><b lang="zh-CN">${SN[i]}</b> ${esc(L10.stageM[i])} · ${L10.stShare(fmt(st.solid), fmt(st.total))}</div>${st.test ? `<div class="sttest">${L10.stTest(fmt(st.test))}</div>` : ''}
    <div class="stn">${note}</div>${eta}</div>`;
}
/* the tests: a stabilising trial when the realm is unstable, the breakthrough at 圆满 (a make-up tribulation for a
   飞升 from the placement test), and the placement test only while it is the way in (first test, one retake in 14 days) */
function testH(note = true) {
  const r = LM.realm(),
    can = LM.canTest(),
    sb = LM.stability(),
    pt = LM.ptOpen();
  let h = '';
  if (!sb.ok)
    h += `<div class="unst"><div class="unsth"><b lang="zh-CN">境界不稳</b> <small>jìngjiè bù wěn</small></div><p>${esc(sb.why === 'acc' ? L10.unstAcc(sb.P, Math.round(sb.acc * 100)) : L10.unstRec(sb.P, Math.round(sb.rec * 100)))}</p>
      <button class="planbtn wide" id="stabGo"><span lang="zh-CN">试炼稳固</span><span>${L10.stabGo}</span></button></div>`;
  if (LM.btOpen()) {
    const mk = LM.makeupOpen();
    h += `<button class="planbtn wide btbtn" id="btGo"${can ? '' : ' disabled'} style="--lc:${rc(mk ? 7 : r + 1)}"><span lang="zh-CN">${mk ? '补劫' : '突破'}</span><span>${esc(mk ? L10.mkGo : L10.btGo(RN[r + 1]))}</span></button>`;
  }
  if (pt === 'first' || pt === 'wait')
    h += `<button class="planbtn wide" id="ptGo"${pt === 'first' ? '' : ' disabled'}>${PLAY}<span>${L10.ptStart}</span></button>`;
  else if (pt === 'retake')
    h += `<button class="ghost wide" id="ptGo">${L10.ptRetake(dateS(tDate(LM.ptRetakeUntil())))}</button>`;
  else if (r > 0 && note) h += `<p class="gnote">${L10.ptClosed}</p>`;
  if (!can && (LM.btOpen() || pt === 'wait'))
    h += `<p class="gnote lockn">${LOCK}<span>${esc(L10.testNext(dateS(tDate(LM.nextTestAt()))))}</span></p>`;
  return h;
}
/* a stabilising trial: the faded words of the level below, as a quiz round; 80 % right steadies the realm */
function stabRun() {
  const W = LM.stabWords(15);
  if (!W.length) return false;
  pendingRun = {
    mode: 'quiz',
    items: W.map(d => ({ k: 'q', d, q: LM.pickType(d) })),
    after: (ok, tot) => {
      const done = LM.stabDone(ok, tot);
      renderCurLv();
      toast(done ? L10.stabOk : L10.stabNo(Math.round((ok / Math.max(1, tot)) * 100)), 5000);
    },
  };
  go('quiz');
  return true;
}
/* guidance (指点): what to work on, ranked by LM.advice(); each with a button that starts the right practice */
let advCur = null,
  advL = 1;
function advText(x) {
  const h = 'HSK ' + x.L;
  switch (x.k) {
    case 'test':
      return [L10.advTest, L10.advTestWhy, L10.advStart];
    case 'f':
      return [L10.advF(fmt(x.n), h), L10.advFWhy, L10.advGo];
    case 's':
      return [L10.advS(fmt(x.n), h), L10.advSWhy, L10.advGo];
    case 'due':
      return [L10.advDue(fmt(x.n), h), L10.advDueWhy, L10.advStart];
    case 'skill':
      return [L10.advSkill(TNAME()[x.q], x.p), L10.advSkillWhy, L10.advGo];
    case 'young':
      return [L10.advYoung(fmt(x.n), h), L10.advYoungWhy(x.days), ''];
    case 'new':
      return [L10.advNew(fmt(x.n), h), L10.advNewWhy, L10.advStart];
    case 'conf':
      return [L10.advConf(esc(x.a.h), esc(x.b.h), x.n), L10.advConfWhy, L10.advGo];
    case 'unstable':
      return [L10.advUnst(x.P), L10.advUnstWhy, L10.stabGo];
    case 'makeup':
      return [L10.advMk, L10.advMkWhy, L10.advStart];
    default:
      return [L10.advDao(x.p), L10.advDaoWhy, ''];
  }
}
function adviceH(max) {
  const A = LM.advice();
  advCur = A.items;
  advL = A.L;
  if (!A.items.length) return `<p class="gnote">${L10.advNone}</p>`;
  return `<ol class="advs">${A.items
    .slice(0, max)
    .map((x, i) => {
      const [t, w, b] = advText(x);
      return `<li class="adv adv-${x.k}"><span class="advn" aria-hidden="true">${i + 1}</span><div class="advt"><b>${t}</b><small>${w}</small></div>${b ? `<button class="ghost advgo" data-adv="${i}">${b}</button>` : ''}</li>`;
    })
    .join('')}</ol>`;
}
function advGo(i) {
  const x = advCur && advCur[i];
  if (!x) return;
  if (x.k === 'test') {
    go('placement');
    return;
  }
  if (x.k === 'unstable') {
    stabRun();
    return;
  }
  if (x.k === 'makeup') {
    go('bt');
    return;
  }
  if (x.k === 'f' || x.k === 's') {
    pendingRun = { mode: 'quiz', items: x.words.map(d => ({ k: 'q', d, q: x.k })) };
    go('quiz');
    return;
  }
  if (x.k === 'skill') {
    pendingRun = { mode: 'quiz', items: LM.quizRound(BY[advL], ROUND_Q, x.q) };
    go('quiz');
    return;
  }
  if (x.k === 'conf') {
    pendingRun = {
      mode: 'quiz',
      items: [
        { k: 'q', d: x.a, q: 'm' },
        { k: 'q', d: x.b, q: 'm' },
        { k: 'q', d: x.a, q: 'f' },
        { k: 'q', d: x.b, q: 'f' },
      ],
    };
    go('quiz');
    return;
  }
  sessionExtra = LM.plan().todayLeft === 0;
  go('session');
}
function renderLvl() {
  const info = LM.level,
    r = LM.realm(),
    cur = LM.curLevel();
  const src = !info
    ? L10.lvSrcDefault
    : !r && info.src === 'manual'
      ? L10.lvSrcOld(info.lv)
      : info.src === 'bt'
        ? L10.lvSrcBt(dateS(tDate(info.at)))
        : L10.lvSrcTest(dateS(tDate(info.at)));
  $('lvlBody').innerHTML =
    `${realmHead(r, true)}<p class="lvsrc">${esc(src)}${r && cur > realmLv(r) ? ' ' + esc(L10.lvAhead(cur)) : ''}</p>${r >= 1 && LM.grades()[r] ? `<p class="lvsrc">${realmHow(r, r)}</p>` : ''}
    ${pathH(r)}${stageH(r)}${testH()}
    <div class="lvadv">${hd('指点', 'zhǐdiǎn', L10.advM)}${adviceH(2)}</div>
    <button class="ghost wide soulbtn" id="soulGo"><span lang="zh-CN">识海</span> ${L10.soulMore} ›</button>
    <p class="gnote">${L10.lvNote}</p>`;
}
function openLvl() {
  lvlOpener = document.activeElement;
  renderLvl();
  lvlSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  lvlSheet.querySelector('.xbtn').focus();
}
function closeLvl() {
  lvlSheet.hidden = true;
  document.body.style.overflow = '';
  lvlOpener?.focus?.();
}
$('curLvBtn').onclick = openLvl;
lvlSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]')) {
    closeLvl();
    return;
  }
  const rp = e.target.closest('[data-rp]');
  if (rp) {
    rpPick(rp);
    return;
  }
  const ad = e.target.closest('[data-adv]');
  if (ad) {
    closeLvl();
    advGo(+ad.dataset.adv);
    return;
  }
  const id = e.target.closest('[id]')?.id;
  if (id === 'ptGo') {
    closeLvl();
    go('placement');
    return;
  }
  if (id === 'btGo') {
    closeLvl();
    go('bt');
    return;
  }
  if (id === 'stabGo') {
    closeLvl();
    stabRun();
    return;
  }
  if (id === 'soulGo') {
    closeLvl();
    go('soul');
  }
});
lvlSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeLvl();
  }
});
/* leaving a test after 10 answers still uses this week's test (so a test going badly can't simply be restarted) */
function leaveTest() {
  if (state.screen === 'placement' && pt && pt.st && !pt.res && pt.st.items.length >= 10) LM.noteTest();
  if (state.screen === 'bt' && bt && bt.st && !bt.res && bt.st.i >= 10) LM.noteTest();
  if (bt) clearTimeout(bt.tm);
}
const lockedH = () =>
  `<div class="qcard ptintro"><div class="big t5" lang="zh-CN">静</div><h3>${L10.testLocked}</h3><p class="sumnote">${esc(L10.testNext(dateS(tDate(LM.nextTestAt()))))}</p><p class="sumnote">${L10.testWhy}</p><button class="next" id="tHome">${L10.sumHome}</button></div>`;
