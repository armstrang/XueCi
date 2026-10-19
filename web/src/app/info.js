/* ---------- tone colours & info sheet ---------- */
const infoSheet = $('infoSheet');
const TONE_PATH = ['M4 6H36', 'M4 17L36 5', 'M4 9Q16 24 23 18T36 5', 'M4 4L36 20', ''];
function renderInfo() {
  $('infoTones').innerHTML = L10.tones
    .map(([n, dsc, ex], i) => {
      const t = i + 1,
        [h, p] = [
          ['妈', 'mā'],
          ['麻', 'má'],
          ['马', 'mǎ'],
          ['骂', 'mà'],
          ['吗', 'ma'],
        ][i];
      return `<div class="tone"><span class="tz t${t}">${h}</span><span class="tp t${t}">${p}</span><svg class="tc t${t}" viewBox="0 0 40 24" aria-hidden="true">${TONE_PATH[i] ? `<path d="${TONE_PATH[i]}" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>` : '<circle cx="20" cy="14" r="3.2" fill="currentColor"/>'}</svg><span class="tn"><b>${n}</b><small>${dsc}</small></span><span class="tm">${esc(ex)}</span></div>`;
    })
    .join('');
  $('infoCred').innerHTML = esc(L10.credit).replace(
    '{src}',
    '<a href="https://github.com/harukicoder/hsk30" target="_blank" rel="noopener">hsk30</a>',
  );
  /* help guide: one <details> per topic (keyboard and TalkBack open them like any button) */
  $('helpList').innerHTML = L10.help
    .map(
      ([k, t, ps]) =>
        `<details class="hlp" data-k="${k}"><summary>${t}</summary>${ps.map(helpBlock).join('')}</details>`,
    )
    .join('');
}
/* '@realms', '@stages', '@elements' and '@gloss' in a help topic become tables: hanzi, pinyin, meaning, explanation */
const GL = [
  ['境界', 'jìngjiè', 'jj'],
  ['突破', 'tūpò', 'tp'],
  ['识海', 'shíhǎi', 'sh'],
  ['五行', 'wǔxíng', 'wx'],
  ['指点', 'zhǐdiǎn', 'zd'],
  ['今日试炼', 'jīnrì shìliàn', 'sl'],
  ['修炼天数', 'xiūliàn tiānshù', 'xl'],
  ['闭关', 'bìguān', 'bg'],
  ['调息', 'tiáoxī', 'tx'],
  ['休息之道', 'xiūxi zhī dào', 'xd'],
  ['境界历程', 'jìngjiè lìchéng', 'lc'],
  ['雷劫', 'léijié', 'lj'],
  ['道基', 'dàojī', 'dj'],
  ['认定', 'rèndìng', 'rd'],
  ['境界不稳', 'jìngjiè bù wěn', 'bw'],
  ['试炼稳固', 'shìliàn wěngù', 'wg'],
  ['补劫', 'bǔjié', 'bj'],
];
/*<seal>*/
GL.push(['仙门', 'xiānmén', 'xm', 1]);
/*</seal>*/
const hrow2 = (hz, py, main, sub, lc) =>
  `<div class="hrow2"${lc ? ` style="--lc:${lc}"` : ''}><span class="hz2"><b lang="zh-CN">${hz}</b><small>${py}</small></span><span class="hm"><em>${main}</em>${sub ? `<small>${sub}</small>` : ''}</span></div>`;
function helpBlock(x) {
  if (x === '@realms')
    return `<div class="htab">${RN.slice(0, TOPR() + 1)
      .map((n, i) =>
        hrow2(n, RPY[i], `${esc(L10.realmM[i])} · ${i ? realmHSK(i) : esc(L10.notTested)}`, esc(L10.realmD[i]), rc(i)),
      )
      .join('')}</div>`;
  if (x === '@stages')
    return `<div class="htab">${SN.map((n, i) => hrow2(n, SPY[i], esc(L10.stageM[i]), esc(L10.stageD[i]), 'var(--acc)')).join('')}</div>`;
  if (x === '@elements')
    return `<div class="htab">${EL5.map(([k, g, a]) => hrow2(`${g} ${ATZ[a][0]}`, `${ELP[k]} · ${ATZ[a][1]}`, `${esc(L10.elName[k])} · ${esc(L10.attrN[a])}`, esc(L10.attrD[a]), `var(--el-${k})`)).join('')}</div>`;
  if (x === '@gloss')
    return `<div class="htab">${GL.filter(g => !g[3] || XC.band)
      .map(([h, py, k]) => {
        const [m, ...more] = L10.gloss[k].split(': ');
        return hrow2(h, py, esc(m), esc(more.join(': ')), 'var(--acc)');
      })
      .join('')}</div>`;
  return `<p>${x}</p>`;
}
let infoOpener = null;
function openInfo(topic) {
  renderInfo();
  infoOpener = document.activeElement;
  infoSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  const d = topic && infoSheet.querySelector(`details[data-k="${topic}"]`);
  if (d) {
    d.open = true;
    d.querySelector('summary').focus({ preventScroll: true });
    requestAnimationFrame(() => d.scrollIntoView({ block: 'start' }));
  } else infoSheet.querySelector('.xbtn').focus();
}
function closeInfo() {
  infoSheet.hidden = true;
  document.body.style.overflow = '';
  infoOpener?.focus?.();
}
$('toneInfo').onclick = () => openInfo();
infoSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]')) closeInfo();
});
infoSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeInfo();
  }
});
