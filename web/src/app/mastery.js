/* Mastery: every word has a level 0–20, worked out by the learning engine (learn.js) from how long the word is
   expected to stay remembered. Levels 0–6 are red, 7–13 yellow, 14–20 green; inside each colour a light shade
   means young and a deep shade means mature. Level 20 = mastered. stats[id] = [right, wrong, level]. */
const MAXL = 20;
const lvBand = s => (s >= 14 ? 'green' : s >= 7 ? 'yellow' : 'red');
const lvAlpha = s => {
  const [lo, hi] = s >= 14 ? [14, 20] : s >= 7 ? [7, 13] : [0, 6];
  return Math.round(26 + (74 * (s - lo)) / (hi - lo));
};
{
  let a = '',
    b = '';
  for (let s = 0; s <= MAXL; s++) {
    a += `.m${s}{--mc:var(--s-${lvBand(s)})}`;
    b += `.m${s}{--mc:color-mix(in srgb,var(--s-${lvBand(s)}) ${lvAlpha(s)}%,var(--surface))}`;
  }
  const st = document.createElement('style');
  st.textContent = a + `@supports (color:color-mix(in srgb,red 50%,blue)){${b}}.mbg{background:var(--mc)}`;
  document.head.appendChild(st);
}

/* entries are [right, wrong, level]; older formats are converted by the store's migrations (and, to be safe, here) */
let stats = ls.get('mm_stats', null);
if (!stats || typeof stats !== 'object' || Array.isArray(stats)) stats = {};
for (const k in stats) {
  const e = stats[k];
  if (!Array.isArray(e)) {
    delete stats[k];
    continue;
  }
  if (e.length < 3) e[2] = Math.max(0, Math.min(MAXL, (e[0] | 0) - (e[1] | 0)));
}
const saveStats = () => ls.set('mm_stats', stats);
const lvl = d => {
  const e = stats[d.id];
  return e && e[0] + e[1] > 0 ? e[2] : -1;
}; // -1 = never practised
const isKnown = d => lvl(d) >= MAXL; // mastered
const mcls = d => {
  const s = lvl(d);
  return s < 0 ? 's-none' : `m${s} mbg`;
};
function summary(arr) {
  const lv = new Array(MAXL + 1).fill(0);
  let none = 0,
    pts = 0;
  for (const d of arr) {
    const s = lvl(d);
    if (s < 0) none++;
    else {
      lv[s]++;
      pts += s;
    }
  }
  const sum = (a, b) => lv.slice(a, b).reduce((x, y) => x + y, 0);
  return {
    lv,
    none,
    red: sum(0, 7),
    yellow: sum(7, 14),
    green: sum(14, MAXL + 1),
    mature: lv[MAXL],
    n: arr.length,
    p: (pts / (MAXL * arr.length)) * 100,
  };
}
const pctTxt = p =>
  (p > 0 && p < 10 ? p.toLocaleString(L10.loc, { maximumFractionDigits: 1 }) : Math.floor(p).toLocaleString(L10.loc)) +
  '%';
function stackH(S) {
  let h = '';
  for (let s = MAXL; s >= 0; s--) if (S.lv[s]) h += `<i class="m${s} mbg" style="width:${(S.lv[s] / S.n) * 100}%"></i>`;
  return h;
}
function stTxt(d) {
  const s = lvl(d);
  if (s < 0) return L10.band.none;
  const e = stats[d.id];
  return L10.stTxt(s, e[0], e[1]);
}
function stH(d) {
  return `<span class="st"><i class="sd ${mcls(d)}"></i>${stTxt(d)}</span>`;
}
const masteredAll = () => DATA.filter(isKnown).length;
