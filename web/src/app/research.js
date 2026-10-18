/* ---------- research data (opt-in, offline) ----------
   For a study of whether the realms match real HSK results, a learner may share their answer history by hand: a code
   like the backup code ("XUECIR1:" + base64url(deflate-raw(JSON))) with the answers (word, time, question type, right
   or wrong, time taken), the realm history and, if they want, their official HSK level, score and date. No name, no
   device id, no contacts; nothing is sent by the app — the learner copies or shares the code themselves. */
let rsOpen = false;
function researchH() {
  /* official results above HSK 6 are one choice ("HSK 6+") until the gate is open: nothing may hint at more */
  const p = ls.get('xc_res', {}) || {},
    opt = (XC.band ? [1, 2, 3, 4, 5, 6, 7, 8, 9] : [1, 2, 3, 4, 5, 6, 7])
      .map(l => `<option value="${l}"${+p.lv === l ? ' selected' : ''}>HSK ${l === 7 && !XC.band ? '6+' : l}</option>`)
      .join('');
  return `<details class="resq" id="resq"${rsOpen ? ' open' : ''}><summary>${L10.rsT}</summary><p class="insnote">${L10.rsWhat}</p>
    <div class="rsf"><label><span>${L10.rsHsk}</span><select id="rsLv"><option value="">–</option>${opt}</select></label>
    <label><span>${L10.rsScore}</span><input id="rsScore" type="number" min="0" max="300" inputmode="numeric" value="${Number.isFinite(p.score) ? p.score : ''}"></label>
    <label><span>${L10.rsDate}</span><input id="rsDate" type="month" value="${/^\d{4}-\d\d$/.test(p.date || '') ? p.date : ''}"></label></div>
    <div class="bkrow"><button class="ghost" id="rsCopy">${L10.rsCopy}</button>${NATIVE('shareText') || navigator.share ? `<button class="ghost pri" id="rsShare">${L10.bkShare}</button>` : ''}</div>
    <p class="insnote">${L10.rsPriv}</p></details>`;
}
function rsProfile() {
  const lv = +($('rsLv')?.value || 0),
    sc = $('rsScore')?.value,
    dt = $('rsDate')?.value || '';
  const p = {};
  if (lv >= 1 && lv <= 9) p.lv = lv;
  if (sc !== '' && Number.isFinite(+sc) && +sc >= 0 && +sc <= 300) p.score = Math.round(+sc);
  if (/^\d{4}-\d\d$/.test(dt)) p.date = dt;
  ls.set('xc_res', p);
  return p;
}
async function researchCode() {
  const lv = LM.level || {},
    o = {
      app: 'xueci',
      kind: 'research',
      v: 1,
      at: Date.now(),
      hsk: rsProfile(),
      realm: LM.realm(),
      lvl: { hist: lv.hist || [], th: lv.th || null, per: lv.per || null, pt: lv.pt || null },
      langs: lang,
      log: LM.allLog().slice(-12000),
    };
  const raw = new TextEncoder().encode(JSON.stringify(o));
  if (canZip) {
    try {
      return 'XUECIR1:' + B64(await pipeBytes(raw, new CompressionStream('deflate-raw')));
    } catch (e) {}
  }
  return 'XUECIR0:' + B64(raw);
}
scrStats.addEventListener(
  'toggle',
  e => {
    if (e.target.id === 'resq') rsOpen = e.target.open;
  },
  true,
);
scrStats.addEventListener('change', e => {
  if (['rsLv', 'rsScore', 'rsDate'].includes(e.target.id)) rsProfile();
});
scrStats.addEventListener('click', async e => {
  const id = e.target.id;
  if (id !== 'rsCopy' && id !== 'rsShare') return;
  const code = await researchCode();
  if (id === 'rsShare') {
    if (NATIVE('shareText')) MMAndroid.shareText(L10.rsT, code);
    else
      try {
        await navigator.share({ title: L10.rsT, text: code });
      } catch (_) {}
    return;
  }
  if (NATIVE('copyText')) {
    MMAndroid.copyText(code);
    toast(L10.rsCopied);
    return;
  }
  try {
    await navigator.clipboard.writeText(code);
    toast(L10.rsCopied);
  } catch (_) {}
});
