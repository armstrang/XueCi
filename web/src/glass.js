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

  /* 7. Full visual effects (v1.15): a field of soft light that drifts slowly behind the glass, drawn by a small WebGL
      shader into a low-resolution canvas under the page (the glass panels show it moving through them). Only with
      html.fx-full; 30 frames a second at most; it settles to a still picture 10 s after the last touch and sleeps
      while the app is in the background or during a test or session. Without WebGL the CSS glow stays as it is. */
  const fxbg = (() => {
    const cv = document.createElement('canvas');
    cv.className = 'fxbg';
    cv.setAttribute('aria-hidden', 'true');
    const lb = document.querySelector('.liquid-bg');
    lb ? lb.after(cv) : document.body.prepend(cv);
    let gl = null;
    try {
      gl = cv.getContext('webgl', { alpha: true, premultipliedAlpha: true, antialias: false, powerPreference: 'low-power' });
    } catch (e) {}
    if (!gl) {
      cv.remove();
      root.classList.add('nogl');
      return null;
    }
    const vs = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}',
      fs = `precision mediump float;uniform vec2 r;uniform float t,k;uniform vec3 c1,c2,c3;
        float b(vec2 p,vec2 c,float s){vec2 d=p-c;return exp(-dot(d,d)/s);}
        void main(){vec2 p=gl_FragCoord.xy/r;p.x*=r.x/r.y;float a=r.x/r.y;
          vec2 q1=vec2(a*(.18+.10*sin(t*.07)),.86+.06*cos(t*.09));
          vec2 q2=vec2(a*(.92+.06*cos(t*.05+1.)),.42+.12*sin(t*.06+2.));
          vec2 q3=vec2(a*(.30+.16*sin(t*.045+4.)),.10+.08*cos(t*.08+1.));
          vec3 c=c1*b(p,q1,.16)*.62+c2*b(p,q2,.12)*.42+c3*b(p,q3,.14)*.40;
          c*=k;float m=max(max(c.r,c.g),c.b);gl_FragColor=vec4(c,min(1.,m));}`;
    const sh = (type, src) => {
      const s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      return s;
    };
    const pr = gl.createProgram();
    gl.attachShader(pr, sh(gl.VERTEX_SHADER, vs));
    gl.attachShader(pr, sh(gl.FRAGMENT_SHADER, fs));
    gl.linkProgram(pr);
    if (!gl.getProgramParameter(pr, gl.LINK_STATUS)) {
      cv.remove();
      return null;
    }
    gl.useProgram(pr);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(pr, 'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    const U = n => gl.getUniformLocation(pr, n),
      uR = U('r'),
      uT = U('t'),
      uK = U('k'),
      uC = [U('c1'), U('c2'), U('c3')];
    /* the colours come from the theme: the level colour, the realm gold, a warm light (resolved through probes) */
    const probe = document.createElement('i');
    probe.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden';
    document.body.appendChild(probe);
    const rgb = v => {
      probe.style.color = v;
      const m = getComputedStyle(probe).color.match(/[\d.]+/g) || [0, 0, 0];
      return [m[0] / 255, m[1] / 255, m[2] / 255];
    };
    function colours() {
      const dark = isDark();
      gl.uniform3fv(uC[0], rgb('var(--acc)'));
      gl.uniform3fv(uC[1], rgb('var(--gold)'));
      gl.uniform3fv(uC[2], rgb(dark ? 'var(--l5)' : '#ffb07a'));
      gl.uniform1f(uK, theme === 'black' ? 0.32 : dark ? 0.42 : 0.7);
    }
    let raf = 0,
      last = 0,
      t0 = performance.now(),
      awake = 0;
    function size() {
      const w = Math.max(64, Math.round(innerWidth / 3)),
        h = Math.max(64, Math.round(innerHeight / 3));
      if (cv.width !== w || cv.height !== h) {
        cv.width = w;
        cv.height = h;
        gl.viewport(0, 0, w, h);
        gl.uniform2f(uR, w, h);
      }
    }
    const on = () =>
      root.classList.contains('fx-full') && !document.hidden && !['session', 'placement', 'bt'].includes(state.screen);
    function draw(now) {
      gl.uniform1f(uT, (now - t0) / 1000);
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    function frame(now) {
      raf = 0;
      if (!on()) return;
      if (now - last >= 33) {
        last = now;
        draw(now);
      }
      if (!reduce && now < awake) raf = requestAnimationFrame(frame);
    }
    function wake() {
      if (!on()) return;
      awake = performance.now() + 10000;
      if (!raf) raf = requestAnimationFrame(frame);
    }
    function refresh() {
      size();
      colours();
      draw(performance.now());
      wake();
    }
    ['pointerdown', 'keydown'].forEach(ev => addEventListener(ev, wake, { passive: true, capture: true }));
    addEventListener('scroll', wake, { passive: true });
    addEventListener('resize', refresh);
    document.addEventListener('visibilitychange', wake);
    new MutationObserver(refresh).observe(root, { attributes: true, attributeFilter: ['class', 'data-theme'] });
    new MutationObserver(refresh).observe(document.body, { attributes: true, attributeFilter: ['data-level', 'data-screen'] });
    try {
      darkMQ && darkMQ.addEventListener('change', refresh);
    } catch (e) {}
    refresh();
    return { wake, refresh, cv };
  })();
  window.mmFxBg = fxbg;

  /* first paint of Home with the lens and the animated ring */
  if (state.screen === 'home') renderHome();
  else if (state.screen === 'stats') renderStats();
})();
