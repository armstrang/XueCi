/* the word list, loaded by boot.js from data/core.json + data/<lang>.json: HSK 1–6, plus HSK 7–9 (data/core-b.json)
   once the gate after 飞升 is open. LEVELS lists the levels that are open; it grows in place when the gate opens. */
const DATA = XC.data;
const LEVELS = [...new Set(DATA.map(d => d.l))].sort((a, b) => a - b),
  NUM = '一二三四五六七八九';
const BY = {},
  UNITS = {};
function indexLevel(l) {
  BY[l] = DATA.filter(d => d.l === l);
  UNITS[l] = Math.max(...BY[l].map(d => d.u));
}
LEVELS.forEach(indexLevel);
const $ = id => document.getElementById(id);

/* storage: ls (store.js) · study language: LANGS and sysLang() (boot.js) */

let langPref = ls.get('mm_lang', 'auto');
if (langPref !== 'auto' && !LANGS.includes(langPref)) langPref = 'auto';
let lang = langPref === 'auto' ? sysLang() : langPref;
let L10 = I18N[lang];
const M = d => (lang === 'en' ? d.em : lang === 'th' ? d.hm : lang === 'vi' ? d.vm : d.m);
const TR = d => (lang === 'en' ? d.et : lang === 'th' ? d.ht : lang === 'vi' ? d.vt : d.t);
const M1 = d => M(d).split(';')[0].trim();
const fmt = n => n.toLocaleString(L10.loc);

const TONE = { 1: 'āēīōūǖĀĒĪŌŪ', 2: 'áéíóúǘÁÉÍÓÚ', 3: 'ǎěǐǒǔǚǍĚǏǑǓ', 4: 'àèìòùǜÀÈÌÒÙ' };
const tone = s => {
  for (const t in TONE) {
    for (const c of TONE[t]) if (s.includes(c)) return +t;
  }
  return 5;
};
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const plain = s => s.normalize('NFD').replace(/\p{M}/gu, '').replace(/ü/g, 'v').replace(/['\s]/g, '').toLowerCase();
const unmark = s => s.normalize('NFD').replace(/\p{M}/gu, '').replace(/đ/g, 'd').replace(/Đ/g, 'D');
const prepWord = d => {
  d.id = d.l + ':' + d.h;
  d.pk = plain(d.p);
};
DATA.forEach(prepWord);
function buildKeys() {
  DATA.forEach(d => {
    const m = M(d).toLowerCase();
    d.key = d.h + ' ' + d.pk + ' ' + m + (lang === 'vi' ? ' ' + unmark(m) : '');
  });
}
buildKeys();
const IDX = new Map(DATA.map(d => [d.id, d]));
/* the gate opened: HSK 7–9 words (already pushed into DATA by XC.loadBand) join every index */
function addBand(words) {
  words.forEach(d => {
    prepWord(d);
    IDX.set(d.id, d);
  });
  buildKeys();
  for (const l of [7, 8, 9])
    if (!LEVELS.includes(l)) {
      LEVELS.push(l);
      indexLevel(l);
    }
  LM.bandAdded();
}
function hzH(d) {
  const c = [...d.h];
  return c.length === d.s.length
    ? c.map((ch, i) => `<span class="t${tone(d.s[i])}">${esc(ch)}</span>`).join('')
    : esc(d.h);
}
function pyH(d) {
  return d.s
    .map((s, i) => (i && /^[aeoāáǎàēéěèōóǒò]/.test(s) ? "'" : '') + `<span class="t${tone(s)}">${esc(s)}</span>`)
    .join('');
}
/* pinyin of the example sentence (vocab field zp; the learned word is in {braces}) */
function zpH(d) {
  return d.zp ? `<div class="zp">${esc(d.zp).replace(/\{([^}]*)\}/, '<mark>$1</mark>')}</div>` : '';
}
function exH(d) {
  const z = esc(d.z),
    w = esc(d.h);
  return z.includes(w) ? z.replace(w, `<mark>${w}</mark>`) : z;
}
function mH(m) {
  const p = m
    .split(';')
    .map(x => x.trim())
    .filter(Boolean);
  return (
    `<b>${esc(p[0])}</b>` +
    p
      .slice(1)
      .map(x => `<span> · ${esc(x)}</span>`)
      .join('')
  );
}
const chip = l => `<span class="lvchip" style="background:var(--l${l})">HSK ${l}</span>`;
const CHEV =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>';
/* realms (境界): 0 凡人 not tested yet · 1–6 studying HSK 1–6 · 7 飞升, 8 真仙, 9 玄仙 studying the HSK 7, 8, 9 tiers
   (behind the gate, which opens when 飞升 is reached by a breakthrough) · 10 大罗 everything mastered.
   Before the gate is open only realms 0–7 exist for the learner: the path ends at 飞升 and a sealed gate.
   Four stages inside a realm. */
const RN = ['凡人', '炼气', '筑基', '金丹', '元婴', '化神', '渡劫', '飞升', '真仙', '玄仙', '大罗'],
  RPY = [
    'fánrén',
    'liànqì',
    'zhùjī',
    'jīndān',
    'yuányīng',
    'huàshén',
    'dùjié',
    'fēishēng',
    'zhēnxiān',
    'xuánxiān',
    'dàluó',
  ];
const SN = ['初期', '中期', '后期', '圆满'],
  SPY = ['chūqī', 'zhōngqī', 'hòuqī', 'yuánmǎn'],
  RS = '凡炼筑金元化渡飞真玄罗';
const TOPR = () => (XC.band ? 10 : 7); /* the highest realm the learner can see */
const realmLv = r => Math.max(1, Math.min(XC.band ? 9 : 6, r)),
  rc = r => (r < 1 ? 'var(--mute)' : r > 9 || (r > 6 && !XC.band) ? 'var(--gold)' : `var(--l${r})`);
const tDate = t => new Date(Date.UTC(2026, 0, 1) + t * 6e4);
const LOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="11" width="14" height="9.5" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>';
const WK = [1, 2, 3, 4, 5, 6, 0],
  wkName = (w, st) =>
    new Date(2026, 0, 4 + w).toLocaleDateString(L10.loc, { weekday: st }); /* 4 Jan 2026 was a Sunday */
