/* ---------- the home-screen widget (v1.17, Android only) ----------
   The widget (XueciWidget.java) cannot run the app's code, so the app hands it ready-made text whenever Home is drawn:
   the realm in hanzi, its pinyin and meaning, the stage and progress, today's plan in one line, cultivation days and
   whether today is practised, plus the realm's colour. Sent only when something changed (MMAndroid.setWidget). Only
   the learner's own realm is shown, as on Home. */
let widgetLast = '';
function syncWidget(today) {
  if (!window.MMAndroid || typeof MMAndroid.setWidget !== 'function') return;
  const r = LM.realm(),
    p = realmPct(r),
    st = LM.stage(r < 1 ? LM.baseLevel() : r),
    k = LM.streak();
  const o = {
    r: RN[r],
    py: RPY[r],
    m: L10.realmM[r] + (r ? ' · ' + realmHSK(r) : ''),
    p: r ? Math.max(0, Math.min(100, p)) : 0,
    s: r && st ? `${SN[st.i]} ${L10.stageM[st.i]} · ${p}%` : L10.rLine0,
    tl: L10.planT || '',
    t: String(today || '')
      .replace(/<[^>]+>/g, '')
      .trim(),
    d: L10.strDays(fmt(k.days)),
    lit: !!k.today,
    c: cardColour(r),
  };
  const j = JSON.stringify(o);
  if (j === widgetLast) return;
  widgetLast = j;
  try {
    MMAndroid.setWidget(j);
  } catch (e) {}
}
