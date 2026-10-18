/* ---------- language menu ---------- */
const langBtn = $('langBtn'),
  langMenu = $('langMenu'),
  langList = $('langList');
const CHECK =
  '<svg class="ck" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>';
const DEVICE =
  '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M11 18.5h2"/></svg>';
function renderLangMenu() {
  const sl = sysLang();
  langList.innerHTML =
    `<button class="lgrow" role="option" data-lang="auto" aria-selected="${langPref === 'auto'}"><span class="lgcode">${DEVICE}</span><span class="nm"><b>${esc(L10.auto)}</b><small lang="${sl}">${esc(I18N[sl].name)}</small></span>${CHECK}</button><div class="msep"></div>` +
    LANGS.map(l => {
      const own = I18N[l].name,
        loc = L10.names[l];
      return `<button class="lgrow" role="option" data-lang="${l}" lang="${l}" aria-selected="${langPref === l}"><span class="lgcode">${l.toUpperCase()}</span><span class="nm"><b>${esc(own)}</b>${loc !== own ? `<small lang="${lang}">${esc(loc)}</small>` : ''}</span>${CHECK}</button>`;
    }).join('');
}
function openLang() {
  renderLangMenu();
  langMenu.hidden = false;
  langBtn.setAttribute('aria-expanded', 'true');
  (langList.querySelector('[aria-selected="true"]') || langList.firstElementChild).focus();
}
function closeLang(focusBtn) {
  langMenu.hidden = true;
  langBtn.setAttribute('aria-expanded', 'false');
  if (focusBtn) langBtn.focus();
}
langBtn.onclick = () => (langMenu.hidden ? openLang() : closeLang(false));
langList.onclick = e => {
  const r = e.target.closest('.lgrow');
  if (!r) return;
  closeLang(true);
  if (r.dataset.lang !== langPref) setLang(r.dataset.lang);
};
langMenu.addEventListener('keydown', e => {
  const rows = [...langList.querySelectorAll('.lgrow')],
    i = rows.indexOf(document.activeElement);
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    rows[(i + 1) % rows.length].focus();
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    rows[(i - 1 + rows.length) % rows.length].focus();
  } else if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeLang(true);
  }
});
function applyStatic() {
  document.documentElement.lang = lang;
  document.querySelectorAll('[data-i18n]').forEach(el => (el.textContent = L10[el.dataset.i18n]));
  document.querySelectorAll('[data-i18n-aria]').forEach(el => el.setAttribute('aria-label', L10[el.dataset.i18nAria]));
  document.querySelectorAll('[data-i18n-ph]').forEach(el => (el.placeholder = L10[el.dataset.i18nPh]));
  $('langCode').textContent = lang.toUpperCase();
  langBtn.title = L10.langHead + ': ' + L10.name;
  langBtn.setAttribute('aria-label', L10.langHead + ': ' + L10.name);
  $('legend').innerHTML = [
    ['妈', 'mā', 1],
    ['麻', 'má', 2],
    ['马', 'mǎ', 3],
    ['骂', 'mà', 4],
    ['吗', 'ma', 5],
  ]
    .map(([h, p, n]) => `<span><b class="t${n}">${h}</b> ${p} ${n < 5 ? L10.tone(n) : L10.neutral}</span>`)
    .join('');
  $('footP').innerHTML = esc(L10.foot).replace(
    '{src}',
    '<a href="https://github.com/harukicoder/hsk30" target="_blank" rel="noopener">hsk30</a>',
  );
  if (FOCUS.includes(state.screen)) $('fTitle').textContent = fTitleOf(state.screen);
  themeLabels();
}
function setLang(pref, silent) {
  const l = pref === 'auto' ? sysLang() : pref;
  /* the meanings of each language are a separate file (data/<lang>.json), loaded the first time it is chosen */
  if (!XC.has(l)) {
    XC.loadLang(l).then(
      () => setLang(pref, silent),
      () => toast(L10.dataFail),
    );
    return;
  }
  langPref = pref;
  ls.set('mm_lang', pref);
  const changed = l !== lang;
  lang = l;
  L10 = I18N[l];
  if (changed) {
    buildKeys();
    applyStatic();
    if (run) {
      const it = run.items[run.i],
        dup = a => new Set(a.map(M1)).size < a.length; /* two options can share a meaning in the new language */
      if (it && it.k === 'q' && it.q === 'm' && !it.done && it.opts && dup(it.opts)) delete it.opts;
      if (it && it.k === 'card' && it.st === 'check' && it.chk.q === 'cm' && dup(it.chk.opts))
        it.chk = Object.assign({ q: 'cm' }, LM.question(it.d, 'cm'));
    }
    refresh();
  }
  if (!silent) toast(pref === 'auto' ? L10.auto + ' · ' + L10.name : L10.name);
}
window.addEventListener('languagechange', () => {
  if (langPref === 'auto' && sysLang() !== lang) setLang('auto', true);
});
