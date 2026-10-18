$('toast').onclick = () => {
  $('toast').hidden = true;
};
/* xc_note: which once-only notes were shown {night, back, amb:{d, n}} */
const note = (() => {
    const o = ls.get('xc_note', {});
    return o && typeof o === 'object' && !Array.isArray(o) ? o : {};
  })(),
  saveNote = () => ls.set('xc_note', note);
const lateNow = () => {
  const h = new Date().getHours();
  return h >= 23 || h < 4;
};
const nightKey = () => new Date(Date.now() - 4 * 36e5).toDateString(); /* 23:00–04:00 is one night */
