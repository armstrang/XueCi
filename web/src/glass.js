/* ================= Liquid Glass interactions ================= */
(function () {
  const reduce = (() => {
    try {
      return matchMedia('(prefers-reduced-motion: reduce)').matches;
    } catch (e) {
      return false;
    }
  })();
  const root = document.documentElement;
  const hasVT = !!document.startViewTransition && !reduce;
  if (window.MMAndroid) root.classList.add('app');
  function buzz(p) {
    try {
      navigator.vibrate && navigator.vibrate(p);
    } catch (e) {}
  }

  /* 1. HSK selectors (Home and Stats): a glass lens slides between levels and can be dragged with a finger */
  const lenses = [];
  function makeLens(pills) {
    const seg = document.createElement('div');
    seg.className = 'lvseg';
    pills.parentNode.insertBefore(seg, pills);
    seg.appendChild(pills);
    const lens = document.createElement('div');
    lens.className = 'lens';
    seg.prepend(lens);
    seg.style.touchAction = 'pan-y';
    let at = null,
      drag = null;
    const cur = () => pills.querySelector('[aria-pressed="true"]');
    function to(btn, animate) {
      if (!btn || !seg.offsetParent) {
        at = null;
        return;
      }
      const sr = seg.getBoundingClientRect(),
        br = btn.getBoundingClientRect(),
        L = br.left - sr.left,
        W = br.width;
      const from = at;
      at = L;
      lens.style.width = W + 'px';
      lens.style.left = L + 'px';
      if (from === null || !animate || reduce || Math.abs(from - L) < 1) return;
      lens.animate(
        [
          { left: from + 'px', transform: 'scale(1,1)' },
          { transform: 'scale(1.18,.9)', offset: 0.45 },
          { left: L + 'px', transform: 'scale(1,1)' },
        ],
        { duration: 380, easing: 'cubic-bezier(.3,1.2,.5,1)' },
      );
    }
    seg.addEventListener('pointerdown', e => {
      if (reduce || at === null) return;
      drag = { x0: e.clientX, start: at, moved: false, id: e.pointerId };
    });
    seg.addEventListener('pointermove', e => {
      if (!drag) return;
      const dx = e.clientX - drag.x0;
      if (!drag.moved) {
        if (Math.abs(dx) < 7) return;
        drag.moved = true;
        try {
          seg.setPointerCapture(drag.id);
        } catch (_) {}
        lens.classList.add('drag');
      }
      const sr = seg.getBoundingClientRect(),
        W = lens.offsetWidth,
        L = Math.max(4, Math.min(sr.width - W - 4, drag.start + dx));
      lens.style.left = L + 'px';
      at = L;
    });
    const end = () => {
      if (!drag) return;
      const d = drag;
      drag = null;
      lens.classList.remove('drag');
      if (!d.moved) return;
      const sr = seg.getBoundingClientRect(),
        c = at + lens.offsetWidth / 2;
      let best = null,
        bd = 1e9;
      pills.querySelectorAll('.lvpill').forEach(b => {
        const r = b.getBoundingClientRect(),
          m = r.left - sr.left + r.width / 2;
        if (Math.abs(m - c) < bd) {
          bd = Math.abs(m - c);
          best = b;
        }
      });
      if (best && best.getAttribute('aria-pressed') !== 'true') {
        buzz(8);
        best.click();
      } else to(best, true);
    };
    seg.addEventListener('pointerup', end);
    seg.addEventListener('pointercancel', end);
    const api = {
      sync: animate => to(cur(), animate),
      reset: () => {
        at = null;
      },
    };
    lenses.push(api);
    return api;
  }
  const homeLens = makeLens(document.getElementById('lvPills'));
  const statLens = makeLens(document.getElementById('stLevels'));
  addEventListener('resize', () =>
    lenses.forEach(l => {
      l.reset();
      l.sync(false);
    }),
  );

  /* 2. on Home the mastery percentage counts up (short, so it never holds you up) */
  let cuT = 0;
  function countUp(el, to) {
    cancelAnimationFrame(cuT);
    const t0 = performance.now(),
      D = 700;
    const step = t => {
      const k = Math.min(1, (t - t0) / D),
        e = 1 - Math.pow(1 - k, 3);
      el.textContent = pctTxt(to * e);
      if (k < 1) cuT = requestAnimationFrame(step);
    };
    cuT = requestAnimationFrame(step);
  }
  window.mmHomeRendered = S => {
    homeLens.sync(true);
    if (reduce) return;
    countUp(document.getElementById('heroPct'), S.p);
  };
  window.mmStatsRendered = () => statLens.sync(true);

  /* 3. opening a screen: it zooms out of the tile you tapped in one quick, smooth motion (opacity + scale only,
      on the compositor); going back, Home settles into place around the tile you came from. */
  const scrOf = s =>
    s === 'home'
      ? document.getElementById('scr-home')
      : s === 'stats'
        ? document.getElementById('scr-stats')
        : s === 'soul'
          ? document.getElementById('scr-soul')
          : document.getElementById('scr-focus');
  let lastTap = null,
    anim = null;
  document.addEventListener(
    'pointerdown',
    e => {
      lastTap = e.target.closest ? e.target.closest('.tile,#hero,.mstats,.planbtn,.chalchip') : null;
    },
    { capture: true, passive: true },
  );
  function originIn(sec, el) {
    const s = sec.getBoundingClientRect();
    if (!el || !el.isConnected || !el.offsetParent) return '50% 120px';
    const r = el.getBoundingClientRect();
    return `${Math.round(r.left + r.width / 2 - s.left)}px ${Math.round(r.top + r.height / 2 - s.top)}px`;
  }
  /* frame watcher: in automatic mode, if screen changes keep running slowly on this phone (median frame over 30 ms
     across several of them), step down to light effects once, remember it, and say so. Never in manual modes. */
  const fw = { iv: [], n: 0, done: !!ls.get('xc_fxd', 0) };
  function watchFrames() {
    if (fw.done || fxPref !== 'auto' || document.visibilityState !== 'visible' || root.classList.contains('fx-low'))
      return;
    let last = 0;
    const t0 = performance.now(),
      tick = t => {
        if (last) fw.iv.push(t - last);
        last = t;
        if (t - t0 < 320) requestAnimationFrame(tick);
        else if (++fw.n >= 4 && fw.iv.length >= 30) {
          const s = fw.iv.slice().sort((a, b) => a - b);
          if (s[s.length >> 1] > 30) {
            fw.done = true;
            ls.set('xc_fxd', 1);
            applyFx();
            toast(L10.fxDown);
          } else if (fw.n >= 12) fw.done = true; /* it ran well: stop watching for this session */
        }
      };
    requestAnimationFrame(tick);
  }
  window.mmTransition = (run, from, to) => {
    const fwd = from === 'home' || to === 'stats' || (from === 'soul' && to !== 'home');
    const tapped = fwd ? lastTap : null;
    lastTap = null;
    const tapRect = tapped && tapped.isConnected ? tapped.getBoundingClientRect() : null;
    lenses.forEach(l => l.reset());
    if (anim) {
      try {
        anim.cancel();
      } catch (_) {}
      anim = null;
    }
    run();
    if (reduce) return;
    const sec = scrOf(to);
    let origin;
    if (fwd) {
      const s = sec.getBoundingClientRect();
      origin = tapRect
        ? `${Math.round(tapRect.left + tapRect.width / 2 - s.left)}px ${Math.round(tapRect.top + tapRect.height / 2 - s.top)}px`
        : '50% 120px';
    } else {
      const el =
        to === 'home'
          ? from === 'session'
            ? document.getElementById('planGo')
            : ['soul', 'bt', 'placement'].includes(from)
              ? document.getElementById('curLvBtn')
              : FOCUS.includes(from)
                ? document.querySelector(`.tile[data-go="${from}"]`)
                : document.getElementById('hero')
          : null;
      origin = originIn(sec, el);
    }
    sec.style.transformOrigin = origin;
    watchFrames();
    const a = sec.animate(
      fwd
        ? [
            { opacity: 0, transform: 'scale(.9)' },
            { opacity: 1, transform: 'none' },
          ]
        : [
            { opacity: 0, transform: 'scale(1.04)' },
            { opacity: 1, transform: 'none' },
          ],
      { duration: fwd ? 280 : 220, easing: 'cubic-bezier(.2,.85,.25,1)' },
    );
    anim = a;
    a.onfinish = a.oncancel = () => {
      if (anim === a) {
        anim = null;
        sec.style.transformOrigin = '';
      }
    };
  };

  /* 4. switching theme spreads the new look out from the option you tapped (Settings) */
  const themeGo = pickTheme;
  pickTheme = (t, btn) => {
    if (!hasVT || !btn) {
      themeGo(t, btn);
      return;
    }
    const r = btn.getBoundingClientRect();
    root.style.setProperty('--vt-x', r.left + r.width / 2 + 'px');
    root.style.setProperty('--vt-y', r.top + r.height / 2 + 'px');
    root.dataset.vt = 'theme';
    try {
      document
        .startViewTransition(() => themeGo(t, btn))
        .finished.finally(() => {
          delete root.dataset.vt;
        });
    } catch (_) {
      themeGo(t, btn);
    }
  };

  /* 5. light haptics (Android app) */
  window.mmFeedback = ok => buzz(ok ? 14 : [16, 60, 26]);
  document.addEventListener(
    'click',
    e => {
      if (e.target.closest && e.target.closest('.tile,.lvpill,#hero,.planbtn,.orb,.hp')) buzz(7);
    },
    { capture: true },
  );

  /* 6. the HSK/unit menus live beside the floating header, not inside it, so their own blur sees the page */
  {
    const fb = document.querySelector('#scr-focus .fbar');
    ['lvMenu', 'uMenu'].forEach(id => fb.appendChild(document.getElementById(id)));
  }

  /* first paint of Home with the lens and the animated ring */
  if (state.screen === 'home') renderHome();
  else if (state.screen === 'stats') renderStats();
})();
