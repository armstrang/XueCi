/* ---------- Soul Sea (识海): the realm, the soul orb, the five elements (五行), today's trial, cultivation days, rest ----------
   Every number comes from the memory model and the answer log on this phone (LM.soul, LM.challenge, LM.streak, LM.restGain). */
const EL5 = [
  ['earth', '土', 'root'],
  ['wood', '木', 'cult'],
  ['water', '水', 'sense'],
  ['metal', '金', 'dao'],
  ['fire', '火', 'insight'],
];
const ATZ = {
  root: ['根基', 'gēnjī'],
  cult: ['修为', 'xiūwéi'],
  sense: ['神识', 'shénshí'],
  dao: ['道心', 'dàoxīn'],
  insight: ['悟性', 'wùxìng'],
};
const TTL = {
  root: ['磐石', 'pánshí'],
  cult: ['苦修', 'kǔxiū'],
  sense: ['明镜', 'míngjìng'],
  dao: ['剑心', 'jiànxīn'],
  insight: ['慧根', 'huìgēn'],
};
const ELP = { earth: 'tǔ', wood: 'mù', water: 'shuǐ', metal: 'jīn', fire: 'huǒ' };
function soulRows(S) {
  const known = EL5.filter(e => S[e[2]] !== null),
    mn = known.length > 1 ? known.reduce((a, b) => (S[b[2]] < S[a[2]] ? b : a)) : null,
    mx = known.length > 1 ? known.reduce((a, b) => (S[b[2]] > S[a[2]] ? b : a)) : null,
    flat = mn && mx && S[mn[2]] === S[mx[2]];
  return EL5.map(e => {
    const [k, g, a] = e,
      v = S[a],
      weak = !flat && e === mn,
      strong = !flat && e === mx && v >= 60;
    const val =
      v === null
        ? L10.unknownV
        : a === 'cult'
          ? L10.cultV(fmt(S.cultDays))
          : a === 'insight'
            ? L10.insightV(S.insightDays)
            : v + '%';
    /* the counts behind the value, so every number can be checked */
    const st = a === 'root' ? LM.stage(S.L) : null,
      x =
        v === null
          ? ''
          : a === 'root' && st
            ? L10.attrX.root(fmt(st.solid), fmt(st.test), fmt(st.total))
            : a === 'sense'
              ? L10.attrX.sense(fmt(S.senseN), fmt(S.senseOf), S.L)
              : a === 'dao'
                ? L10.attrX.dao(fmt(S.daoOk), fmt(S.daoN))
                : '';
    return `<div class="elrow el-${k}${weak ? ' weak' : ''}"><span class="elg" aria-hidden="true"><b lang="zh-CN">${g}</b><small>${ELP[k]}</small></span><div class="elt">
      <div class="eln"><b lang="zh-CN">${ATZ[a][0]}</b><small class="hpy">${ATZ[a][1]}</small><span>${esc(L10.attrN[a])}</span><em>${esc(val)}</em></div>
      <span class="elbar"><i style="width:${v === null ? 0 : Math.max(2, v)}%"></i></span><small>${esc(L10.attrD[a])}${x ? `<br><b class="elx">${esc(x)}</b>` : ''}</small>
      ${weak ? `<p class="eltip">${esc(L10.attrTip[a])}</p>` : ''}${strong ? `<p class="eltitle">${L10.titleL(`<span lang="zh-CN">${TTL[a][0]}</span> ${TTL[a][1]} · ${esc(L10.attrTitle[a])}`)}</p>` : ''}</div></div>`;
  }).join('');
}
function weekH() {
  const S = LM.studyDays(),
    today = LM.dayOf(LM.now());
  let h = '';
  for (let d = today - 6; d <= today; d++) {
    const w = new Date(Date.now() - (today - d) * 864e5).getDay(),
      c = S.has(d) ? 'on' : LM.isRest(d) ? 'rest' : d === today ? 'today' : 'off';
    h += `<span class="wd ${c}"><i aria-hidden="true">${c === 'rest' ? '闭' : ''}</i><small>${esc(wkName(w, 'short'))}</small></span>`;
  }
  return h;
}
function restH(g) {
  if (!g) return `<p class="gnote">${L10.restEmpty}</p>`;
  const mx = Math.max(g.now, g.day, g.two) || 1,
    f = x => (x < 10 ? x.toLocaleString(L10.loc, { maximumFractionDigits: 1 }) : fmt(Math.round(x)));
  return `<p class="sumnote">${L10.restWhy(f(g.S))}</p><div class="rgain">${[
    [L10.restNow, g.now],
    [L10.restDay, g.day],
    [L10.restTwo, g.two],
  ]
    .map(
      ([n, v]) =>
        `<div class="skrow"><span>${n}</span><span class="mbar"><span class="stack"><i style="width:${Math.max(2, (v / mx) * 100)}%;background:var(--el-water)"></i></span></span><b>+${f(v)}</b></div>`,
    )
    .join('')}</div>
    <p class="gnote">${L10.restNote}</p>`;
}
function renderSoul() {
  const r = LM.realm(),
    st = LM.stage(),
    S = LM.soul(),
    c = LM.challenge(),
    k = LM.streak(),
    info = LM.level,
    rest = LM.rest;
  $('soulTitle').textContent = L10.soulT;
  let hist = ((info && info.hist) || []).slice();
  if (!hist.length && info && info.src === 'test') hist = [[r, info.at]];
  hist.reverse();
  const cc = Math.min(c.cnt, c.n);
  $('soulBody').innerHTML = `<div class="soulhero" style="--lc:${rc(r)}">
      <div class="orbwrap">${SOUL.wheel(S, 300)}<canvas class="orb" id="orb" role="img" aria-label="${esc(L10.orbL(fmt(S.words)))}"></canvas></div>
      ${realmHead(r, true)}<p class="orbpick" id="orbPick" aria-live="polite">${S.words ? L10.orbHint : L10.orbEmpty}</p></div>
    <section class="scard prog">${hd('修炼之路', 'xiūliàn zhī lù', L10.pathM)}${pathH(r)}${stageH(r)}${testH()}</section>
    <section class="scard advc">${hd('指点', 'zhǐdiǎn', L10.advM)}<p class="gnote advintro">${L10.advIntro}</p>${adviceH(6)}</section>
    <section class="scard">${hd('五行', 'wǔxíng', L10.elM)}${soulRows(S)}</section>
    <section class="scard chal${c.done ? ' done' : ''}">${hd('今日试炼', 'jīnrì shìliàn', L10.chalM)}<p class="chtxt">${L10.chalTxt(skName(c.k), c.n, c.a)}</p>
      <div class="skrow"><span>${cc}/${c.n}</span><span class="mbar"><span class="stack"><i style="width:${Math.min(100, (c.cnt / c.n) * 100)}%;background:var(--acc)"></i></span></span><b>${c.cnt ? c.acc + '%' : '–'}</b></div>
      <p class="gnote">${c.done ? L10.chalDone : L10.chalWhy}${c.total ? ' · ' + L10.chalTot(c.total) : ''}</p>${c.done ? '' : `<button class="ghost wide" id="chalGo">${L10.chalGo}</button>`}</section>
    <section class="scard">${hd('修炼天数', 'xiūliàn tiānshù', L10.strM)}<div class="strk"><b>${L10.strDays(k.days)}</b><div class="week">${weekH()}</div></div>
      <p class="gnote">${L10.strNote}</p><p class="gnote">${
        rest.length
          ? esc(
              L10.medDays(
                WK.filter(w => rest.includes(w))
                  .map(w => wkName(w, 'long'))
                  .join(', '),
              ),
            )
          : L10.medNone
      } <button class="linkbtn" id="medSet">${L10.medSet}</button></p></section>
    <section class="scard">${hd('休息之道', 'xiūxi zhī dào', L10.restM)}${restH(LM.restGain())}</section>
    <section class="scard">${hd('境界历程', 'jìngjiè lìchéng', L10.histM)}${hist.length ? `<div class="hist">${hist.map(([hr, t]) => `<div class="hrow" style="--lc:${rc(hr)}"><b lang="zh-CN">${RN[hr]}</b><small class="hpy">${RPY[hr]}</small><span>${esc(L10.realmM[hr])}</span><small>${dateS(tDate(t))}</small></div>`).join('')}</div>` : `<p class="gnote">${L10.histEmpty}</p>`}
      ${info && info.per ? `<div class="glbl">${L10.ptPer}</div>${perBars(info.per)}` : ''}</section>`;
  SOUL.mount($('orb'), {
    realm: r,
    stage: st ? st.i : 0,
    onPick: d => {
      const el = $('orbPick');
      if (!el) return;
      el.innerHTML = d
        ? `<b class="hzs">${hzH(d)}</b> ${pyH(d)} · ${esc(M1(d))} · <span class="st">${stTxt(d)}</span>`
        : L10.orbHint;
    },
  });
}
scrSoul.addEventListener('click', e => {
  const rp = e.target.closest('[data-rp]');
  if (rp) {
    rpPick(rp);
    return;
  }
  const ad = e.target.closest('[data-adv]');
  if (ad) {
    advGo(+ad.dataset.adv);
    return;
  }
  const id = e.target.closest('[id]')?.id;
  if (id === 'soulBack') {
    back();
    return;
  }
  if (id === 'soulHelp') {
    openInfo('soul');
    return;
  }
  if (id === 'btGo') {
    go('bt');
    return;
  }
  if (id === 'ptGo') {
    go('placement');
    return;
  }
  if (id === 'medSet') {
    openGoal(false, null, 'rest');
    return;
  }
  if (id === 'chalGo') {
    const c = LM.challenge();
    pendingRun = { mode: 'quiz', items: LM.quizRound(pool(), ROUND_Q, c.k) };
    go('quiz');
  }
});
