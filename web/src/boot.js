/* ================= Start-up =================
   The page shows only the background glow while it starts: the theme and the level colour are set at once from the
   localStorage safety copy (so a dark theme never flashes white), then
     1. the progress store is opened (store.js),
     2. the word data is loaded from beside the page: data/core.json (hanzi, pinyin, example sentences, levels) and the
        meanings in the study language (data/<lang>.json); other languages load when they are chosen,
     3. old saved data is migrated to the current schema,
     4. the app runs (script #xc-app), then the Liquid Glass layer (script #xc-glass). Both are run as ordinary
        scripts, so everything they declare is global, as before. */
const LANGS = ['id', 'en', 'th', 'vi'];
/* 'auto' follows the phone/browser language; unsupported languages fall back to English */
function sysLang() {
  const list = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || ''];
  for (const n of list) {
    const c = String(n).toLowerCase().slice(0, 2);
    if (c === 'id' || c === 'in' || c === 'ms') return 'id';
    if (c === 'en' || c === 'th' || c === 'vi') return c;
  }
  return 'en';
}
const XC = (() => {
  const root = document.documentElement;
  root.classList.add('booting');
  try {
    const t = JSON.parse(localStorage.getItem('hsk16_theme'));
    if (t && t !== 'auto') root.setAttribute('data-theme', t);
    const ui = JSON.parse(localStorage.getItem('hsk16_ui'));
    if (ui && ui.level >= 1 && ui.level <= 9) document.body.dataset.level = ui.level;
  } catch (e) {}

  const COLS = { id: ['m', 't'], en: ['em', 'et'], th: ['hm', 'ht'], vi: ['vm', 'vt'] };
  /* the word list comes in parts: HSK 1–6 (data/core.json + data/<lang>.json) and, once the gate after 飞升 is open,
     HSK 7–9 (data/core-b.json + data/<lang>-b.json). Every part keeps the languages it has loaded. */
  const parts = [{ key: '', words: null, langs: new Set() }];
  const data = [];
  const get = path =>
    fetch(path).then(r => {
      if (!r.ok) throw new Error(path + ' ' + r.status);
      return r.json();
    });
  const toWords = c =>
    c.rows.map(r => {
      const d = {};
      c.cols.forEach((k, i) => {
        if (r[i] != null) d[k] = r[i];
      });
      return d;
    });
  function addLang(l, part, j) {
    const [a, b] = COLS[l];
    if (!j || j.rows.length !== part.words.length)
      throw new Error(`data/${l}${part.key}.json does not match the word list`);
    j.rows.forEach((r, i) => {
      part.words[i][a] = r[0];
      part.words[i][b] = r[1];
    });
    part.langs.add(l);
  }
  const partLang = (l, part) =>
    part.langs.has(l) ? Promise.resolve() : get(`data/${l}${part.key}.json`).then(j => addLang(l, part, j));
  const has = l => parts.every(p => p.langs.has(l));
  function loadLang(l) {
    return Promise.all(parts.map(p => partLang(l, p)));
  }
  /* HSK 7–9: loaded at start when the gate is already open, or right when it opens; returns the new words */
  let band = null;
  function loadBand() {
    if (band) return band;
    const part = { key: '-b', words: null, langs: new Set() };
    const langs = [...parts[0].langs];
    band = get('data/core-b.json')
      .then(c => {
        part.words = toWords(c);
        return Promise.all(langs.map(l => get(`data/${l}-b.json`).then(j => addLang(l, part, j))));
      })
      .then(() => {
        parts.push(part);
        data.push(...part.words);
        return part.words;
      })
      .catch(e => {
        band = null;
        throw e;
      });
    return band;
  }
  /* the ids of the HSK 7–9 words, without opening them (checking a backup code from a learner past the gate) */
  let bandIdSet = null;
  function bandIds() {
    if (!bandIdSet)
      bandIdSet = get('data/core-b.json').then(c => {
        const l = c.cols.indexOf('l'),
          h = c.cols.indexOf('h');
        return new Set(c.rows.map(r => r[l] + ':' + r[h]));
      });
    return bandIdSet;
  }
  function run(id) {
    const s = document.createElement('script');
    s.textContent = document.getElementById(id).textContent;
    document.body.appendChild(s);
  }
  function fail(e) {
    console.error(e);
    root.classList.remove('booting');
    document.body.insertAdjacentHTML(
      'beforeend',
      '<p class="bootfail">Data kata gagal dimuat. Tutup aplikasi lalu buka lagi.<br>The word list could not be loaded. Close the app and open it again.</p>',
    );
  }
  async function start() {
    const core = get('data/core.json');
    await STORE.open();
    const pref = ls.get('mm_lang', 'auto'),
      lang = pref !== 'auto' && LANGS.includes(pref) ? pref : sysLang(),
      lv = ls.get('xc_lvl', null),
      gate = !!(lv && lv.gate);
    const [c, m] = await Promise.all([core, get(`data/${lang}.json`)]);
    parts[0].words = toWords(c);
    addLang(lang, parts[0], m);
    data.push(...parts[0].words);
    if (gate) await loadBand();
    STORE.migrate({ ids: new Set(data.map(d => d.l + ':' + d.h)) });
    run('xc-app');
    run('xc-glass');
    root.classList.remove('booting');
  }
  start().catch(fail);
  return {
    data,
    loadLang,
    loadBand,
    bandIds,
    has,
    get band() {
      return parts.length > 1;
    },
  };
})();
