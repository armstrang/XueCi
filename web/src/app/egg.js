/* ---------- an easter egg (v1.16, Josh): tap the XueCi wordmark seven times ----------
   A vermilion seal stamps the screen with 天外有天 ("above the sky there is another sky"), a saying every one of the
   app's languages knows in its own words. Before its time the seal reads 封 (sealed); once the seal has opened it reads
   开 (open). Nothing else changes; it only tells the curious that curiosity is welcome. Remembered in xc_note.egg. */
const eggOv = $('eggOv');
let eggTaps = [],
  eggT = 0;
function eggShow() {
  const open = XC.band;
  eggOv.innerHTML = `<div class="eggbox"><div class="eggseal" aria-hidden="true"><span lang="zh-CN">${open ? '开' : '封'}</span></div>
    <p class="egghz" lang="zh-CN">天外有天</p><p class="eggpy">tiān wài yǒu tiān</p>
    <p class="eggm">${esc(L10.eggM)}</p><p class="eggs">${esc(open ? L10.eggOpen : L10.eggSealed)}</p></div>`;
  eggOv.setAttribute('aria-label', '天外有天 · ' + L10.eggM);
  eggOv.hidden = false;
  try {
    navigator.vibrate && navigator.vibrate([12, 60, 18]);
  } catch (e) {}
  note.egg = (note.egg || 0) + 1;
  saveNote();
  clearTimeout(eggT);
  eggT = setTimeout(eggHide, 5200);
}
function eggHide() {
  clearTimeout(eggT);
  eggOv.hidden = true;
}
eggOv.addEventListener('click', eggHide);
document.querySelector('.brand.hp').addEventListener('click', () => {
  const t = Date.now();
  eggTaps = eggTaps.filter(x => t - x < 2500);
  eggTaps.push(t);
  if (eggTaps.length >= 7) {
    eggTaps = [];
    eggShow();
  }
});
