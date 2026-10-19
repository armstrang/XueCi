/* ---------- the cultivation card (v1.16, Josh's list): a picture of where you are, to share ----------
   Drawn on a canvas (1080 × 1350, the 4:5 shape most apps show whole) from the numbers on this phone: the realm and its
   ring, the realm's meaning and stage, cultivation days, solid words at the realm's level, words practised. Always the
   dark ink look with the realm's colour and gold, so it reads the same in every chat. Only the learner's own realm is
   drawn (nothing about realms they cannot see). The picture is made here and goes only to the app the learner picks:
   Android's share sheet through MMAndroid.shareImage, else the Web Share API, else a download. */
const shareSheet = $('shareSheet');
let shareOpener = null,
  shareUrl = '',
  shareBlob = null;
/* the realm colours on dark (the card is always dark): 凡人 grey, HSK 1–9, gold at the top */
const CARD_C = [
  '#a3a9b3',
  '#6fd08f',
  '#5cc8cf',
  '#6dbbea',
  '#94a3f5',
  '#bf9af0',
  '#ec8dbd',
  '#e8bd57',
  '#ff8f78',
  '#a7b4dc',
];
const cardColour = r => (r < 1 ? CARD_C[0] : r > 9 || (r > 6 && !XC.band) ? '#e6c36a' : CARD_C[r]);
async function drawCard() {
  const r = LM.realm(),
    L = r < 1 ? LM.baseLevel() : LM.realmLevel(r),
    st = LM.stage(r < 1 ? L : r),
    S = LM.soul(),
    k = LM.streak(),
    p = realmPct(r),
    col = cardColour(r),
    gold = '#e6c36a';
  const hz = getComputedStyle(document.documentElement).getPropertyValue('--f-hz').trim() || 'serif',
    tx = getComputedStyle(document.body).fontFamily;
  try {
    await Promise.all([
      document.fonts.load(`900 150px ${hz}`, RN[r]),
      document.fonts.load(`800 52px ${tx}`, L10.realmM[r]),
      document.fonts.load(`400 30px ${tx}`, 'a'),
    ]);
  } catch (e) {}
  const W = 1080,
    H = 1350,
    cv = document.createElement('canvas');
  cv.width = W;
  cv.height = H;
  const g = cv.getContext('2d');
  /* ink background, the realm's light behind the ring, a little gold low on the left */
  let gr = g.createLinearGradient(0, 0, 0, H);
  gr.addColorStop(0, '#121b29');
  gr.addColorStop(1, '#06090e');
  g.fillStyle = gr;
  g.fillRect(0, 0, W, H);
  const glow = (x, y, rad, c, a) => {
    const q = g.createRadialGradient(x, y, 0, x, y, rad);
    q.addColorStop(
      0,
      c +
        Math.round(a * 255)
          .toString(16)
          .padStart(2, '0'),
    );
    q.addColorStop(1, c + '00');
    g.fillStyle = q;
    g.fillRect(0, 0, W, H);
  };
  glow(540, 560, 620, col, 0.3);
  glow(120, 1240, 520, gold, 0.12);
  /* faint rings like ripples on the Soul Sea */
  g.strokeStyle = 'rgba(255,255,255,.05)';
  g.lineWidth = 2;
  for (const rad of [330, 400, 480]) {
    g.beginPath();
    g.arc(540, 560, rad, 0, Math.PI * 2);
    g.stroke();
  }
  /* the wordmark and the date */
  g.textBaseline = 'alphabetic';
  g.textAlign = 'left';
  g.font = `800 54px ${tx}`;
  g.fillStyle = '#f4f6fa';
  g.fillText('Xue', 80, 120);
  const xw = g.measureText('Xue').width;
  g.fillStyle = '#6dbbea';
  g.fillText('Ci', 80 + xw, 120);
  g.font = `800 20px ${tx}`;
  g.fillStyle = gold;
  g.letterSpacing = '7px';
  g.fillText('MANDARIN', 82, 154);
  g.letterSpacing = '0px';
  g.textAlign = 'right';
  g.font = `500 26px ${tx}`;
  g.fillStyle = 'rgba(244,246,250,.62)';
  g.fillText(new Date().toLocaleDateString(L10.loc, { day: 'numeric', month: 'short', year: 'numeric' }), W - 80, 120);
  /* the ring: track, then the realm's progress from gold into the realm's colour */
  const cx = 540,
    cy = 560,
    R = 250;
  g.lineCap = 'round';
  g.lineWidth = 22;
  g.strokeStyle = 'rgba(255,255,255,.1)';
  g.beginPath();
  g.arc(cx, cy, R, 0, Math.PI * 2);
  g.stroke();
  if (r && p > 0) {
    const a0 = -Math.PI / 2,
      a1 = a0 + (Math.PI * 2 * Math.min(100, p)) / 100,
      lg = g.createLinearGradient(cx - R, cy + R, cx + R, cy - R);
    lg.addColorStop(0, gold);
    lg.addColorStop(1, col);
    g.strokeStyle = lg;
    g.shadowColor = col;
    g.shadowBlur = 24;
    g.beginPath();
    g.arc(cx, cy, R, a0, a1);
    g.stroke();
    g.shadowBlur = 0;
  }
  /* inside the ring: the realm in hanzi, its pinyin, the progress */
  g.textAlign = 'center';
  g.fillStyle = col;
  g.font = `900 ${RN[r].length > 2 ? 120 : 150}px ${hz}`;
  g.shadowColor = col;
  g.shadowBlur = 30;
  g.fillText(RN[r], cx, cy + 20);
  g.shadowBlur = 0;
  g.fillStyle = 'rgba(244,246,250,.72)';
  g.font = `500 34px ${tx}`;
  g.fillText(RPY[r], cx, cy + 82);
  g.fillStyle = '#f4f6fa';
  g.font = `400 58px ${tx}`;
  g.fillText(r ? p + '%' : L10.chipTest, cx, cy + 160);
  /* under the ring: what the realm means, its level and the stage */
  const fit = (t, weight, size, max) => {
    let s = size;
    do g.font = `${weight} ${s}px ${tx}`;
    while (g.measureText(t).width > max && (s -= 2) > 24);
  };
  const mean = L10.realmM[r] + (r ? ' · ' + realmHSK(r) : '');
  fit(mean, 800, 54, W - 140);
  g.fillStyle = '#f4f6fa';
  g.fillText(mean, cx, 905);
  if (st && r) {
    /* the stage: its hanzi in the serif face, then its name */
    const sn = SN[st.i],
      nm = L10.stageM[st.i];
    g.font = `900 34px ${hz}`;
    const w1 = g.measureText(sn).width;
    fit(nm, 500, 34, W - 220 - w1);
    const w2 = g.measureText(nm).width,
      x0 = cx - (w1 + 14 + w2) / 2;
    g.textAlign = 'left';
    g.fillStyle = col;
    g.font = `900 34px ${hz}`;
    g.fillText(sn, x0, 960);
    g.fillStyle = 'rgba(244,246,250,.72)';
    fit(nm, 500, 34, W - 220 - w1);
    g.fillText(nm, x0 + w1 + 14, 960);
    g.textAlign = 'center';
  }
  /* three numbers */
  const nums = [
    [fmt(k.days), L10.cardDays],
    [st ? `${fmt(st.solid)}/${fmt(st.total)}` : '–', L10.cardSolid(L)],
    [fmt(S.words), L10.cardWords],
  ];
  nums.forEach(([n, lab], i) => {
    const x = 200 + i * 340;
    g.fillStyle = i === 1 ? col : '#f4f6fa';
    fit(n, 800, 64, 300);
    g.fillText(n, x, 1105);
    g.fillStyle = 'rgba(244,246,250,.62)';
    fit(lab, 500, 26, 300);
    g.fillText(lab, x, 1148);
  });
  g.fillStyle = 'rgba(255,255,255,.08)';
  g.fillRect(370, 1060, 2, 100);
  g.fillRect(710, 1060, 2, 100);
  /* the five elements as five small seals along the bottom */
  const EC = { wood: '#62c983', fire: '#ff7a66', earth: '#e2b75a', metal: '#c3cad6', water: '#6aa8f0' };
  EL5.forEach(([k2, h2, a], i) => {
    const x = cx + (i - 2) * 76,
      y = 1250,
      v = S[a];
    g.lineWidth = 3;
    g.strokeStyle = EC[k2];
    g.globalAlpha = v === null ? 0.35 : 0.35 + 0.65 * (v / 100);
    g.beginPath();
    g.arc(x, y, 26, 0, Math.PI * 2);
    g.stroke();
    g.fillStyle = EC[k2];
    g.font = `900 26px ${hz}`;
    g.fillText(h2, x, y + 9);
    g.globalAlpha = 1;
  });
  g.font = `500 22px ${tx}`;
  g.fillStyle = 'rgba(244,246,250,.45)';
  g.fillText('XueCi Mandarin', cx, 1318);
  return cv;
}
async function openShare() {
  shareOpener = document.activeElement;
  shareSheet.hidden = false;
  document.body.style.overflow = 'hidden';
  $('shareTitle').textContent = L10.shareT;
  $('shareGo').textContent = L10.shareGo;
  $('shareNote').textContent = L10.shareNote;
  const img = $('shareImg');
  img.removeAttribute('src');
  img.alt = '';
  shareSheet.querySelector('.xbtn').focus();
  const cv = await drawCard();
  shareBlob = await new Promise(res => cv.toBlob(res, 'image/png'));
  if (shareUrl) URL.revokeObjectURL(shareUrl);
  shareUrl = URL.createObjectURL(shareBlob);
  img.src = shareUrl;
  const r = LM.realm();
  img.alt = `${RN[r]} ${RPY[r]} · ${L10.realmM[r]}`;
}
function closeShare() {
  shareSheet.hidden = true;
  document.body.style.overflow = '';
  shareOpener?.focus?.();
}
async function doShare() {
  if (!shareBlob) return;
  const r = LM.realm(),
    text = L10.shareTxt(RN[r], L10.realmM[r], realmHSK(r));
  if (window.MMAndroid && MMAndroid.shareImage) {
    const b64 = await new Promise(res => {
      const fr = new FileReader();
      fr.onload = () => res(String(fr.result).split(',')[1]);
      fr.readAsDataURL(shareBlob);
    });
    if (!MMAndroid.shareImage(b64, text)) toast(L10.shareFail);
    return;
  }
  const file = new File([shareBlob], 'xueci-card.png', { type: 'image/png' });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], text });
      return;
    }
  } catch (e) {
    if (e && e.name === 'AbortError') return;
  }
  const a = document.createElement('a');
  a.href = shareUrl;
  a.download = 'xueci-card.png';
  document.body.appendChild(a);
  a.click();
  a.remove();
}
shareSheet.addEventListener('click', e => {
  if (e.target.closest('[data-close]')) closeShare();
  else if (e.target.closest('#shareGo')) doShare();
});
shareSheet.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    closeShare();
  }
});
