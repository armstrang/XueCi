/* Interface text of XueCi Mandarin: one file per study language (id, en, th, vi), each key defined once.
   Values are strings, or arrow functions for text with numbers in it (they may use the helpers below).
   Text that names what lies past the gate goes between the seal comments at the end of each file; make_assets.py
   moves it into the sealed part. */
const I18N = {};

/* "HSK 1" or "HSK 1–m" */
const r = m => (m === 1 ? 'HSK 1' : `HSK 1–${m}`);
