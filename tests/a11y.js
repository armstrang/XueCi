/* Accessibility audit run inside the page: names for controls (what TalkBack reads), text contrast against the
   colour actually behind it (solid colours composited up the tree; gradients count by their first stop), and the
   size of touch targets. Returns {names, contrast, targets} lists of problems. */
() => {
  const vis = el => {
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' && !el.closest('[hidden],[aria-hidden="true"]');
  };
  const nameOf = el => {
    const l = el.getAttribute('aria-label');
    if (l && l.trim()) return l.trim();
    const lb = el.getAttribute('aria-labelledby');
    if (lb) return lb.split(/\s+/).map(id => document.getElementById(id)?.textContent || '').join(' ').trim();
    if (el.labels && el.labels.length) return [...el.labels].map(x => x.textContent).join(' ').trim();
    if (el.placeholder) return el.placeholder;
    const t = [...el.childNodes].map(n => (n.nodeType === 3 ? n.textContent : n.nodeType === 1 && !n.closest('[aria-hidden="true"]') ? n.textContent : '')).join('').trim();
    return t || el.getAttribute('title') || '';
  };
  const names = [];
  document.querySelectorAll('button,a[href],input:not([type=hidden]),select,textarea,[role=button],[role=option],[role=radio],[tabindex="0"]').forEach(el => {
    if (!vis(el)) return;
    if (!nameOf(el)) names.push((el.id ? '#' + el.id : el.tagName.toLowerCase()) + '.' + (el.className.baseVal ?? el.className).toString().split(' ').slice(0, 2).join('.'));
  });
  const parse = c => {
    const m = c.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
    return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
  };
  const firstStop = bi => {
    const m = bi.match(/rgba?\([^)]+\)/);
    return m ? parse(m[0]) : null;
  };
  const over = (top, under) => {
    const a = top[3];
    return [0, 1, 2].map(i => top[i] * a + under[i] * (1 - a)).concat(1);
  };
  const lum = c => {
    const f = v => ((v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
  };
  const rootBg = parse(getComputedStyle(document.body).backgroundColor) || [255, 255, 255, 1];
  const bgOf = el => {
    const layers = [];
    for (let e = el; e && e !== document.documentElement; e = e.parentElement) {
      const s = getComputedStyle(e);
      const c = parse(s.backgroundColor);
      if (c && c[3] > 0) layers.push(c);
      else if (s.backgroundImage !== 'none') {
        const f = firstStop(s.backgroundImage);
        if (f && f[3] > 0.05) layers.push(f);
      }
      if (c && c[3] >= 1) break;
    }
    let b = rootBg.slice();
    for (let i = layers.length - 1; i >= 0; i--) b = over(layers[i], b);
    return b;
  };
  const contrast = [];
  const seen = new Set();
  document.querySelectorAll('body *').forEach(el => {
    if (!vis(el) || !el.childNodes.length) return;
    if (el.closest('.lvseg [aria-pressed="true"]')) return; /* drawn on the lens, a sibling, not a parent */
    const own = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
    if (!own) return;
    const s = getComputedStyle(el);
    if (+s.opacity === 0) return;
    let fg = parse(s.color);
    if (!fg) return;
    let op = 1;
    for (let e = el; e; e = e.parentElement) op *= +getComputedStyle(e).opacity;
    const bg = bgOf(el);
    fg = over([fg[0], fg[1], fg[2], fg[3] * op], bg);
    const L1 = lum(fg), L2 = lum(bg), ratio = (Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05);
    const px = parseFloat(s.fontSize), big = px >= 24 || (px >= 18.66 && +s.fontWeight >= 700);
    const need = big ? 3 : 4.5;
    if (ratio < need) {
      const key = el.tagName + '.' + el.className + ':' + el.textContent.trim().slice(0, 18);
      if (!seen.has(key)) {
        seen.add(key);
        contrast.push(`${ratio.toFixed(2)} <${need} "${el.textContent.trim().slice(0, 24)}" ${el.tagName.toLowerCase()}.${String(el.className).split(' ')[0]}`);
      }
    }
  });
  const targets = [];
  document.querySelectorAll('button,a[href],[role=button],[role=radio]').forEach(el => {
    if (!vis(el)) return;
    const r = el.getBoundingClientRect();
    if (r.width < 24 || r.height < 24) targets.push(`${Math.round(r.width)}x${Math.round(r.height)} ${el.id ? '#' + el.id : el.className}`);
  });
  return { names, contrast, targets };
}
