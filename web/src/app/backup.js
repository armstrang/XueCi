/* ---------- progress backup / restore ----------
   A backup is one line of text: "XUECI1:" + base64url(deflate-raw(JSON)), or "XUECI0:" + base64url(JSON)
   where compression isn't available. It can be copied, shared, and pasted into another install.
   The time of the last copy or share is kept (xc_bk) so the sheet can say when the last backup was made; after a
   month without one a small dot shows on the Home button. */
const bkSheet = $('bkSheet'),
  bkCode = $('bkCode'),
  bkMsg = $('bkMsg');
let bkMode = null,
  bkPending = null,
  bkOpener = null;
const NATIVE = n => !!(window.MMAndroid && typeof MMAndroid[n] === 'function');
const canZip = typeof CompressionStream === 'function' && typeof DecompressionStream === 'function';
const B64 = u => {
  let s = '';
  for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
const UNB64 = t => {
  t = t.replace(/-/g, '+').replace(/_/g, '/');
  while (t.length % 4) t += '=';
  const s = atob(t),
    u = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i);
  return u;
};
const pipeBytes = async (u, stream) =>
  new Uint8Array(await new Response(new Blob([u]).stream().pipeThrough(stream)).arrayBuffer());
const practisedN = st => Object.values(st).filter(e => e[0] + e[1] > 0).length;
const bkDate = t => new Date(t).toLocaleDateString(L10.loc, { day: 'numeric', month: 'long', year: 'numeric' });
const BK_OLD = 30; /* days before a new backup is suggested */
const bkLastAt = () => {
  const t = ls.get('xc_bk', 0);
  return Number.isFinite(t) && t > 0 ? t : 0;
};
const bkAge = () => {
  const t = bkLastAt();
  return t ? Math.floor((Date.now() - t) / 864e5) : null;
};
/* worth a reminder: some real progress, and no backup yet or the last one is over a month old */
const bkDue = () => {
  const a = bkAge();
  return practisedN(stats) >= 30 && (a === null || a > BK_OLD);
};
function bkNoted() {
  ls.set('xc_bk', Date.now());
  bkDot();
}
function bkDot() {
  const d = bkDue();
  $('bkBtn').classList.toggle('due', d);
  $('setBtn').classList.toggle('due', d); /* the quiet dot shows on the Settings button, where Backup now lives */
}
function bkLastLine() {
  const a = bkAge(),
    el = $('bkLast');
  el.textContent = a === null ? L10.bkNever : L10.bkLast(bkDate(bkLastAt()), a);
  el.classList.toggle('old', bkDue());
}
async function makeCode() {
  const raw = new TextEncoder().encode(
    JSON.stringify({
      app: 'xueci',
      v: 2,
      at: Date.now(),
      stats,
      mem: LM.exportMem(),
      goal: LM.goal,
      w: LM.params,
      lvl: LM.level,
      rest: LM.rest,
      tests: LM.tests,
      days: [...LM.studyDays()].sort((a, b) => a - b).slice(-730),
      ui: { level: state.level, unitBy: state.unitBy, qt: qType },
      lang: langPref,
      theme,
    }),
  );
  if (canZip) {
    try {
      return 'XUECI1:' + B64(await pipeBytes(raw, new CompressionStream('deflate-raw')));
    } catch (e) {}
  }
  return 'XUECI0:' + B64(raw);
}
async function readCode(text) {
  const m = String(text || '')
    .replace(/\s+/g, '')
    .match(/XUECI([01]):([A-Za-z0-9_-]+)/);
  if (!m) return null;
  try {
    let u = UNB64(m[2]);
    if (m[1] === '1') {
      if (!canZip) return null;
      u = await pipeBytes(u, new DecompressionStream('deflate-raw'));
    }
    const o = JSON.parse(new TextDecoder().decode(u));
    if (!o || o.app !== 'xueci' || !o.stats || typeof o.stats !== 'object') return null;
    /* the gate past 飞升 comes back only with what it took to open it: a breakthrough to 飞升 in the realm history and
       HSK 6 words that are actually solid in the code (half of them). An edited code that just adds the gate loses it
       and meets the make-up tribulation instead. */
    if (o.lvl && o.lvl.gate) {
      const h = Array.isArray(o.lvl.hist) ? o.lvl.hist : [],
        bt = h.some(e => Array.isArray(e) && e[0] >= 7 && e[2] === 'bt'),
        m = o.mem && typeof o.mem === 'object' ? o.mem : {},
        solid6 = BY[6].filter(d => m[d.id] && Array.isArray(m[d.id].w) && +m[d.id].w[1] >= 10).length;
      if (!bt || solid6 < BY[6].length * 0.5) {
        o.lvl = Object.assign({}, o.lvl);
        delete o.lvl.gate;
        delete o.lvl.gs;
      }
    }
    /* a code from past the gate: HSK 7–9 ids are checked against the HSK 7–9 file without opening anything yet */
    const extra = o.lvl && o.lvl.gate && !XC.band ? await XC.bandIds().catch(() => null) : null;
    const known = k => IDX.has(k) || !!(extra && extra.has(k));
    const st = {};
    for (const k in o.stats) {
      const e = o.stats[k];
      if (!known(k) || !Array.isArray(e) || e.length < 2 || !e.every(x => Number.isFinite(x) && x >= 0)) continue;
      const r = Math.floor(e[0]),
        w = Math.floor(e[1]);
      st[k] = [r, w, Math.max(0, Math.min(MAXL, Math.floor(e.length > 2 ? e[2] : r - w)))];
    }
    return {
      stats: st,
      at: +o.at || Date.now(),
      ui: o.ui,
      lang: o.lang,
      theme: o.theme,
      mem: o.mem ? LM.importMem(o.mem, extra) : null,
      goal: 'goal' in o ? o.goal : undefined,
      w: o.w,
      lvl: o.lvl,
      rest: o.rest,
      tests: o.tests,
      days: o.days,
    };
  } catch (e) {
    return null;
  }
}
function bkRow() {
  const r = $('bkRow');
  if (bkMode === 'make')
    r.innerHTML = `<button class="ghost" id="bkCopy">${L10.bkCopy}</button>${NATIVE('shareText') || navigator.share ? `<button class="ghost pri" id="bkShare">${L10.bkShare}</button>` : ''}`;
  else if (bkPending)
    r.innerHTML = `<button class="ghost" id="bkCancel">${L10.cancel}</button><button class="danger solid" id="bkApply">${L10.bkApply}</button>`;
  else
    r.innerHTML = `<button class="ghost" id="bkPaste">${L10.bkPaste}</button><button class="ghost pri" id="bkCheck">${L10.bkCheck}</button>`;
}
function say(msg, bad) {
  bkMsg.textContent = msg || '';
  bkMsg.classList.toggle('bad', !!bad);
}
function bkShow(mode) {
  bkMode = mode;
  bkPending = null;
  say('');
  const menu = mode === 'menu',
    make = mode === 'make';
  $('bkOpts').hidden = !menu;
  $('bkWork').hidden = menu;
  if (menu) bkLastLine();
  $('bkTitle').textContent = menu ? L10.bkT : make ? L10.bkTitleMake : L10.bkTitleRestore;
  $('bkLead').textContent = menu ? L10.bkNote : make ? L10.bkLeadMake(fmt(practisedN(stats))) : L10.bkLeadRestore;
  bkCode.readOnly = make;
  bkCode.value = '';
  bkRow();
  if (make)
    makeCode().then(c => {
      if (bkMode === 'make') bkCode.value = c;
    });
  (menu ? bkSheet.querySelector('.bkopt') : make ? $('bkCopy') : $('bkPaste'))?.focus();
}
function openBackup() {
  bkOpener = document.activeElement;
  bkSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  bkShow('menu');
}
/* Back / Escape: from a code view go back to the two choices, then close */
function bkBack() {
  if (bkMode && bkMode !== 'menu') bkShow('menu');
  else closeBk();
}
function closeBk() {
  bkSheet.hidden = true;
  bkMode = null;
  bkPending = null;
  document.body.style.overflow = '';
  bkOpener?.focus?.();
}
async function bkCopyCode() {
  const t = bkCode.value;
  if (!t) return;
  if (NATIVE('copyText')) {
    MMAndroid.copyText(t);
    bkNoted();
    toast(L10.bkCopied);
    return;
  }
  try {
    await navigator.clipboard.writeText(t);
    bkNoted();
    toast(L10.bkCopied);
  } catch (e) {
    bkCode.focus();
    bkCode.select();
    try {
      document.execCommand('copy') && (bkNoted(), toast(L10.bkCopied));
    } catch (_) {}
  }
}
async function bkShareCode() {
  const t = bkCode.value;
  if (!t) return;
  const title = L10.bkShareText(bkDate(Date.now()));
  if (NATIVE('shareText')) {
    MMAndroid.shareText(title, title + ':\n' + t);
    bkNoted();
    return;
  }
  try {
    await navigator.share({ title, text: t });
    bkNoted();
  } catch (e) {}
}
async function bkPasteCode() {
  let t = '';
  if (NATIVE('pasteText')) t = MMAndroid.pasteText() || '';
  else {
    try {
      t = await navigator.clipboard.readText();
    } catch (e) {}
  }
  if (t) {
    bkCode.value = t;
    bkPending = null;
    say('');
    bkRow();
  } else bkCode.focus();
}
async function bkCheckCode() {
  const b = await readCode(bkCode.value);
  if (!b) {
    say(L10.bkBad, true);
    return;
  }
  bkPending = b;
  say(L10.bkConfirm(fmt(practisedN(b.stats)), bkDate(b.at), fmt(practisedN(stats))));
  bkRow();
  $('bkApply')?.focus();
}
async function bkApply() {
  const b = bkPending;
  if (!b) return;
  /* past the gate: the HSK 7–9 words join first, so their progress has words to belong to */
  if (b.lvl && b.lvl.gate && !XC.band) {
    try {
      const w = await XC.loadBand();
      if (w.some(d => !d.id)) addBand(w);
    } catch (e) {
      toast(L10.dataFail);
      return;
    }
  }
  stats = b.stats;
  LM.replace(b.mem || {}, b.goal, b.w);
  LM.restoreLevel(b.lvl);
  LM.restoreExtra({ tests: b.tests, rest: b.rest, days: b.days });
  syncRest(); /* older codes (v1) have no memory states: their levels are kept as "needs confirming" */
  if (b.ui && LEVELS.includes(b.ui.level)) {
    const ub = b.ui.unitBy || {};
    LEVELS.forEach(l => {
      const u = ub[l];
      state.unitBy[l] = Number.isInteger(u) && u >= 0 && u <= UNITS[l] ? u : 1;
    });
    state.level = b.ui.level;
    if (['auto', 'm', 'f', 's', 'l', 'c', 'p', 't', 'exam'].includes(b.ui.qt)) qType = b.ui.qt;
  }
  if ((b.lang === 'auto' || LANGS.includes(b.lang)) && b.lang !== langPref) setLang(b.lang, true);
  if (themeList().includes(b.theme) && b.theme !== theme) applyTheme(b.theme, true);
  closeBk();
  setLevel(state.level); /* saves the level/unit, restarts cards and quiz, redraws */
  toast(L10.bkDone);
}
$('bkBtn').onclick = openBackup;
bkSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]')) {
    closeBk();
    return;
  }
  const opt = e.target.closest('[data-bk]');
  if (opt) {
    bkShow(opt.dataset.bk);
    return;
  }
  const id = e.target.id;
  if (id === 'bkCopy') bkCopyCode();
  else if (id === 'bkShare') bkShareCode();
  else if (id === 'bkPaste') bkPasteCode();
  else if (id === 'bkCheck') bkCheckCode();
  else if (id === 'bkApply') bkApply();
  else if (id === 'bkCancel') {
    bkPending = null;
    say('');
    bkRow();
  }
});
bkSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    bkBack();
  }
});
bkCode.addEventListener('input', () => {
  if (bkMode === 'restore' && (bkPending || bkMsg.textContent)) {
    bkPending = null;
    say('');
    bkRow();
  }
});
