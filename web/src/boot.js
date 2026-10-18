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
    if (ui && ui.level >= 1 && ui.level <= 6) document.body.dataset.level = ui.level;
  } catch (e) {}

  const COLS = { id: ['m', 't'], en: ['em', 'et'], th: ['hm', 'ht'], vi: ['vm', 'vt'] };
  const have = new Set();
  let data = null;
  const get = path =>
    fetch(path).then(r => {
      if (!r.ok) throw new Error(path + ' ' + r.status);
      return r.json();
    });
  function addLang(l, j) {
    const [a, b] = COLS[l];
    if (!j || j.rows.length !== data.length) throw new Error('data/' + l + '.json does not match the word list');
    j.rows.forEach((r, i) => {
      data[i][a] = r[0];
      data[i][b] = r[1];
    });
    have.add(l);
  }
  function loadLang(l) {
    if (have.has(l)) return Promise.resolve();
    return get(`data/${l}.json`).then(j => addLang(l, j));
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
      lang = pref !== 'auto' && LANGS.includes(pref) ? pref : sysLang();
    const [c, m] = await Promise.all([core, get(`data/${lang}.json`)]);
    data = c.rows.map(r => {
      const d = {};
      c.cols.forEach((k, i) => {
        if (r[i] != null) d[k] = r[i];
      });
      return d;
    });
    addLang(lang, m);
    STORE.migrate({ ids: new Set(data.map(d => d.l + ':' + d.h)) });
    run('xc-app');
    run('xc-glass');
    root.classList.remove('booting');
  }
  start().catch(fail);
  return {
    get data() {
      return data;
    },
    loadLang,
    has: l => have.has(l),
  };
})();
