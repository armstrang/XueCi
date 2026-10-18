/* ---------- daily study reminder (Android): one notification a day at the chosen time, skipped on days with practice ---------- */
const canRemind = () => NATIVE('setReminder');
let rem = Object.assign({ on: false, h: 19, m: 0 }, ls.get('xc_rem', {})),
  remKey = '',
  studiedMark = '';
function remBody() {
  const P = LM.plan(),
    g = LM.goal,
    min = Math.max(5, P.minutes);
  return g && g.t !== 'none'
    ? L10.remGoal(min, g.t === 'exam' ? L10.gExamChip(g.lv, dateS(g.date)) : 'HSK ' + g.lv)
    : L10.remFree(min);
}
function syncReminder() {
  if (!canRemind()) return;
  const body = remBody(),
    k = JSON.stringify([rem, body, L10.remTitle, L10.remChannel]);
  if (k === remKey) return;
  remKey = k;
  try {
    MMAndroid.setReminder(!!rem.on, rem.h | 0, rem.m | 0, L10.remTitle, body, L10.remChannel);
  } catch (e) {}
}
function syncRest() {
  if (NATIVE('setRestDays'))
    try {
      MMAndroid.setRestDays(LM.rest.join(','));
    } catch (e) {}
}
function studied() {
  if (!NATIVE('markStudied')) return;
  const d = new Date().toDateString();
  if (d === studiedMark) return;
  studiedMark = d;
  try {
    MMAndroid.markStudied();
  } catch (e) {}
}
const notifOK = () => !NATIVE('notifStatus') || MMAndroid.notifStatus() === 'granted';
function askNotif(cb) {
  if (notifOK()) {
    cb(true);
    return;
  }
  window.mmNotifResult = g => {
    window.mmNotifResult = null;
    cb(!!g);
  };
  try {
    MMAndroid.requestNotifications();
  } catch (e) {
    window.mmNotifResult = null;
    cb(false);
  }
}
const hhmm = r => `${String(r.h).padStart(2, '0')}:${String(r.m).padStart(2, '0')}`;

let toastT;
function toast(msg, ms) {
  const t = $('toast');
  t.textContent = msg;
  t.hidden = false;
  t.classList.toggle('long', !!ms);
  clearTimeout(toastT);
  toastT = setTimeout(() => (t.hidden = true), ms || 2000);
}
