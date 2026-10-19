/* ---------- the gate after 飞升 ----------
   What lies beyond 飞升 stays hidden until 飞升 is reached by a breakthrough: before that nothing in the
   app hints at them (the realm path just ends at 飞升; Josh wants a real surprise). When it opens, the HSK 7–9 word files are
   loaded (they ship inside the app, nothing is downloaded) and a short ceremony shows what was behind it: the three
   new realms one by one, each step at the learner's own pace (a tap), every animation a quick fade or scale.
   Restored from a backup on another phone: the gate simply opens with a welcome, no ceremony. */
const gateOv = $('gateOv');
let gateStep = -1;
function openGate(ceremony) {
  return XC.loadBand()
    .then(words => {
      if (words && words.some(d => !d.id)) addBand(words);
      refresh();
      renderCurLv();
      if (ceremony && !(LM.level && LM.level.gs)) gateShow();
      else {
        LM.gateSeen();
        toast(L10.gateWelcome);
        if (state.screen === 'bt') go('home');
      }
    })
    .catch(e => {
      console.error(e);
      toast(L10.dataFail);
    });
}
/*<seal>*/
const GATE_R = [8, 9, 10];
function gateRender() {
  const n = BY[7] && BY[8] && BY[9] ? BY[7].length + BY[8].length + BY[9].length : 0;
  const seals = GATE_R.map(
    (r, i) =>
      `<div class="gseal${gateStep > i ? ' on' : ''}" style="--lc:${rc(r)}"><b lang="zh-CN">${RN[r]}</b><small>${RPY[r]}</small><span>${esc(L10.realmM[r])}</span></div>`,
  ).join('');
  const txt = gateStep === 0 ? L10.gate0 : gateStep <= 3 ? esc(L10.realmD[GATE_R[gateStep - 1]]) : L10.gate4(fmt(n));
  gateOv.innerHTML = `<div class="gatebox"><div class="gdoor${gateStep >= 4 ? ' open' : ''}" aria-hidden="true"><span lang="zh-CN">仙</span><span lang="zh-CN">门</span></div>
    <div class="gtitle"><b lang="zh-CN">仙门</b> <small>xiānmén</small></div><div class="gseals">${seals}</div>
    <p class="gtxt" aria-live="polite">${txt}</p>
    <button class="next gnext" id="gateNext">${gateStep >= 4 ? L10.gateEnter : L10.gateOn}</button></div>`;
  $('gateNext').focus();
}
function gateShow() {
  gateStep = 0;
  gateOv.setAttribute('aria-label', '仙门 xiānmén'); /* set only now: before the gate nothing may name it */
  gateOv.hidden = false;
  document.body.style.overflow = 'hidden';
  gateRender();
}
function gateNext() {
  if (gateStep >= 4) {
    gateClose();
    return;
  }
  gateStep++;
  gateRender();
}
function gateClose() {
  gateOv.hidden = true;
  gateStep = -1;
  document.body.style.overflow = '';
  LM.gateSeen();
  go('soul');
}
gateOv.addEventListener('click', e => {
  if (e.target.closest('#gateNext') || e.target === gateOv || e.target.closest('.gatebox')) gateNext();
});
gateOv.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    gateClose();
  }
});
/*</seal>*/
