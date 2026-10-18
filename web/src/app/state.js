const ui = ls.get('hsk16_ui', {});
let state = {
  level: LEVELS.includes(ui.level) ? ui.level : 1,
  unitBy: Object.assign({ 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1 }, ui.unitBy || {}),
  q: '',
  shown: 60,
  hide: false,
  weak: false,
  screen: 'home',
};
let qType = ['auto', 'm', 'f', 's', 'l', 'c', 'p', 't', 'exam'].includes(ui.qt) ? ui.qt : 'auto';
const saveUI = () => ls.set('hsk16_ui', { level: state.level, unitBy: state.unitBy, qt: qType });
const unit = () => state.unitBy[state.level];
const pad = n => String(n).padStart(2, '0');
const FOCUS = ['list', 'card', 'quiz', 'session', 'placement', 'bt'];
const fTitleOf = s => L10[s === 'placement' ? 'ptT' : s === 'bt' ? 'btT' : s];

/* theme: one button cycles auto → light → dark */
const TH_ICON = {
  auto: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v17A8.5 8.5 0 0 0 12 3.5z" fill="currentColor"/></svg>',
  light:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4.5"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/></svg>',
  dark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/></svg>',
  black:
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/><circle cx="18.5" cy="4.5" r="1.3"/><circle cx="21.2" cy="8.6" r=".85"/></svg>',
};
/* the Liquid Glass layer adds a fourth theme, true black (window.MM_THEMES); without it: auto → light → dark */
const themeList = () => window.MM_THEMES || ['auto', 'light', 'dark'];
let theme = 'auto';
const themeBtn = $('themeBtn');
const darkMQ = (() => {
  try {
    return matchMedia('(prefers-color-scheme: dark)');
  } catch (e) {
    return null;
  }
})();
function isDark() {
  return theme === 'dark' || theme === 'black' || (theme === 'auto' && !!darkMQ && darkMQ.matches);
}
/* tell the Android app which colours to give the status and navigation bars (--bar / --bar2 from the CSS) */
function notifyNative() {
  try {
    if (!window.MMAndroid) return;
    const cs = getComputedStyle(document.documentElement),
      top = cs.getPropertyValue('--bar').trim(),
      bot = cs.getPropertyValue('--bar2').trim();
    if (MMAndroid.setBars && /^#[0-9a-f]{6}$/i.test(top))
      MMAndroid.setBars(top, /^#[0-9a-f]{6}$/i.test(bot) ? bot : top, isDark());
    else if (MMAndroid.setTheme) MMAndroid.setTheme(isDark());
  } catch (e) {}
}
function themeLabels() {
  const n = L10.th[theme];
  themeBtn.title = L10.theme + ': ' + n;
  themeBtn.setAttribute('aria-label', L10.theme + ': ' + n + '. ' + L10.tap);
}
function applyTheme(t, persist) {
  if (!themeList().includes(t)) t = 'auto';
  theme = t;
  const r = document.documentElement;
  if (t !== 'auto') r.setAttribute('data-theme', t);
  else if (persist) r.removeAttribute('data-theme');
  themeBtn.innerHTML = TH_ICON[t];
  themeLabels();
  notifyNative();
  if (persist) {
    ls.set('hsk16_theme', t);
    toast(L10.theme + ': ' + L10.th[t]);
  }
  if (state.screen === 'soul') requestAnimationFrame(() => renderSoul());
}
themeBtn.onclick = () => {
  const L = themeList();
  applyTheme(L[(L.indexOf(theme) + 1) % L.length], true);
};
try {
  darkMQ && darkMQ.addEventListener('change', notifyNative);
} catch (e) {}
{
  const t = ls.get('hsk16_theme', null);
  if (t) applyTheme(t, false);
  else {
    const cur = document.documentElement.getAttribute('data-theme');
    applyTheme(cur === 'light' || cur === 'dark' ? cur : 'auto', false);
  }
}
