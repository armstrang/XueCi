/* ---------- pronunciation: the phone's text-to-speech (MMAndroid.speak), or the browser's speechSynthesis ---------- */
const SPK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 9.5v5h3.5L12 19V5L7.5 9.5z" fill="currentColor" stroke-width="1.6"/><path class="w1" d="M15.5 9a4 4 0 0 1 0 6"/><path class="w2" d="M18 6.5a7.5 7.5 0 0 1 0 11"/></svg>';
const canSpeak = () =>
  (window.MMAndroid && typeof MMAndroid.speak === 'function') ||
  ('speechSynthesis' in window && typeof SpeechSynthesisUtterance === 'function');
function spk(text, cls) {
  return canSpeak()
    ? `<button class="spk${cls || ''}" data-say="${esc(text)}" aria-label="${esc(L10.listen)}" title="${esc(L10.listen)}">${SPK}</button>`
    : '';
}
let spkOn = null;
function spkMark(b) {
  spkUnmark();
  if (b && b.isConnected) {
    b.classList.add('on');
    spkOn = b;
  }
}
function spkUnmark() {
  if (spkOn) {
    spkOn.classList.remove('on');
    spkOn = null;
  }
}
window.mmSpeakEnd = spkUnmark;
function speak(text, btn) {
  if (window.MMAndroid && typeof MMAndroid.speak === 'function') {
    const st = MMAndroid.ttsStatus ? MMAndroid.ttsStatus() : 'ready';
    if (st === 'missing' || st === 'unsupported') {
      toast(L10.ttsMissing);
      if (MMAndroid.openTtsSettings) setTimeout(() => MMAndroid.openTtsSettings(), 1200);
      return;
    }
    if (st === 'none') {
      toast(L10.ttsNone);
      return;
    }
    MMAndroid.speak(text, 0.9);
    spkMark(btn);
    return;
  }
  try {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = 'zh-CN';
    u.rate = 0.9;
    const v = speechSynthesis.getVoices().find(v => /^zh[-_]?(CN|Hans)?/i.test(v.lang) && !/TW|HK/i.test(v.lang));
    if (v) u.voice = v;
    u.onend = u.onerror = spkUnmark;
    speechSynthesis.speak(u);
    spkMark(btn);
  } catch (e) {}
}
/* capture phase, so tapping the speaker never flips a card or opens anything else */
document.addEventListener(
  'click',
  e => {
    const b = e.target.closest && e.target.closest('.spk');
    if (!b) return;
    e.preventDefault();
    e.stopPropagation();
    const it = run && run.items[run.i];
    if (it && it.k === 'card' && it.st === 'front') it.heard = true;
    speak(b.dataset.say, b);
  },
  true,
);
