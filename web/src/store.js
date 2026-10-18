/* ================= Progress store =================
   Everything a learner has done stays on this device, in the WebView's IndexedDB (database "xueci", object store
   "kv"). Keys and values are the same as before v1.12: JSON text under the old key names, which must never be renamed.
   The app reads and writes through `ls` without waiting. On start every key is loaded into memory, and each change is
   written to IndexedDB right after (all changes of one moment in a single transaction) and also copied to
   localStorage as a safety copy. If IndexedDB can't be opened, the app keeps working on localStorage alone, as it
   did before v1.12.

   Schema versions (stored under xc_schema):
     1  up to v1.7   mm_stats {id: [right, wrong] or [right, wrong, level]}, hsk16_known (an older list of known
                     words), mm_lang, hsk16_ui, hsk16_theme
     2  v1.8–v1.11   + xc_mem, xc_log, xc_logA, xc_goal, xc_w, xc_fit, xc_onb, xc_lvl, xc_rem, xc_tests, xc_rest,
                     xc_game, xc_amb, xc_note (all in localStorage)
     3  v1.12        everything in IndexedDB; new: xc_days (study days brought back by a backup code), xc_bk (when the
                     last backup code was made)
   Migrations run in order, once, on the data in memory, and never delete a key. */
const STORE = (() => {
  const SCHEMA = 3,
    DB = 'xueci',
    OS = 'kv';
  const mem = new Map();
  let db = null,
    mode = 'ls',
    from = SCHEMA,
    dirty = new Set(),
    queued = false,
    fails = 0;

  const lsSet = (k, v) => {
    try {
      if (v == null) localStorage.removeItem(k);
      else localStorage.setItem(k, v);
    } catch (e) {
      /* full or blocked: the safety copy is best effort */
    }
  };
  const lsAll = () => {
    const out = new Map();
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i),
          v = localStorage.getItem(k);
        if (v != null) out.set(k, v);
      }
    } catch (e) {}
    return out;
  };

  function openDb() {
    return new Promise((resolve, reject) => {
      if (typeof indexedDB === 'undefined' || !indexedDB) return reject(new Error('no IndexedDB'));
      const r = indexedDB.open(DB, 1);
      r.onupgradeneeded = () => r.result.createObjectStore(OS);
      r.onsuccess = () => resolve(r.result);
      r.onerror = () => reject(r.error);
      r.onblocked = () => reject(new Error('IndexedDB blocked'));
      setTimeout(() => reject(new Error('IndexedDB timeout')), 5000);
    });
  }
  function readAll(d) {
    return new Promise((resolve, reject) => {
      const tx = d.transaction(OS, 'readonly'),
        st = tx.objectStore(OS),
        keys = st.getAllKeys(),
        vals = st.getAll();
      tx.oncomplete = () => resolve(new Map(keys.result.map((k, i) => [String(k), vals.result[i]])));
      tx.onerror = tx.onabort = () => reject(tx.error);
    });
  }

  /* load everything into memory: IndexedDB when it already holds the data, otherwise the data in localStorage
     (the first start of v1.12, or IndexedDB was emptied) which is then written to IndexedDB in one go */
  async function open() {
    try {
      db = await openDb();
      const saved = await readAll(db);
      mode = 'idb';
      if (saved.has('xc_schema')) {
        saved.forEach((v, k) => mem.set(k, v));
        return;
      }
      lsAll().forEach((v, k) => {
        mem.set(k, v);
        dirty.add(k);
      });
    } catch (e) {
      db = null;
      mode = 'ls';
      lsAll().forEach((v, k) => mem.set(k, v));
    }
    try {
      navigator.storage && navigator.storage.persist && navigator.storage.persist().catch(() => {});
    } catch (e) {}
  }

  const J = k => {
    try {
      return JSON.parse(mem.get(k));
    } catch (e) {
      return null;
    }
  };
  /* the schema version of the data in memory: stored, or recognised from the keys an older version wrote */
  function version() {
    const v = +J('xc_schema');
    if (v) return v;
    const keys = [...mem.keys()];
    if (keys.some(k => k.startsWith('xc_'))) return 2;
    if (mem.has('mm_stats') || mem.has('hsk16_known')) return 1;
    return SCHEMA;
  }
  const MIGRATIONS = {
    /* 1 → 2: per-word records become [right, wrong, level]; a list of known words from the oldest versions becomes
       records (only words that still exist) */
    1(ctx) {
      let st = J('mm_stats');
      if (!st || typeof st !== 'object' || Array.isArray(st)) {
        st = {};
        const known = J('hsk16_known');
        if (Array.isArray(known))
          known.forEach(id => {
            if (ctx.ids.has(id)) st[id] = [1, 0];
          });
      }
      for (const k in st) {
        const e = st[k];
        if (!Array.isArray(e)) {
          delete st[k];
          continue;
        }
        if (e.length < 3) e[2] = Math.max(0, Math.min(20, (e[0] | 0) - (e[1] | 0)));
      }
      put('mm_stats', JSON.stringify(st));
    },
    /* 2 → 3: the data moves to IndexedDB unchanged (done by open()); nothing to convert */
    2() {},
  };
  function migrate(ctx) {
    from = version();
    for (let v = from; v < SCHEMA; v++) MIGRATIONS[v](ctx);
    if (J('xc_schema') !== SCHEMA) put('xc_schema', String(SCHEMA));
    flush();
  }

  function put(k, v) {
    if (v == null) mem.delete(k);
    else mem.set(k, v);
    lsSet(k, v);
    dirty.add(k);
    if (!queued) {
      queued = true;
      setTimeout(flush, 0);
    }
  }
  /* all changes waiting are written in one transaction; on a failure they are tried again a little later, and
     after three failures the app keeps going on localStorage */
  function flush() {
    queued = false;
    if (mode !== 'idb' || !db || !dirty.size) return;
    const keys = [...dirty];
    dirty.clear();
    const retry = () => {
      keys.forEach(k => dirty.add(k));
      if (++fails >= 3) {
        mode = 'ls';
        return;
      }
      setTimeout(flush, 1500);
    };
    try {
      const tx = db.transaction(OS, 'readwrite'),
        st = tx.objectStore(OS);
      for (const k of keys) {
        const v = mem.get(k);
        if (v == null) st.delete(k);
        else st.put(v, k);
      }
      tx.oncomplete = () => {
        fails = 0;
      };
      tx.onerror = tx.onabort = retry;
    } catch (e) {
      retry();
    }
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) flush();
  });

  return {
    open,
    migrate,
    put,
    flush,
    SCHEMA,
    get: k => (mem.has(k) ? mem.get(k) : null),
    keys: () => [...mem.keys()],
    info: () => ({ mode, from, schema: SCHEMA, keys: mem.size }),
  };
})();

/* the app's view of the store: JSON values under the old key names */
const ls = {
  get(k, f) {
    const v = STORE.get(k);
    if (v == null) return f;
    try {
      return JSON.parse(v);
    } catch (e) {
      return f;
    }
  },
  set(k, v) {
    let s;
    try {
      s = JSON.stringify(v);
    } catch (e) {
      return;
    }
    STORE.put(k, s);
  },
  remove(k) {
    STORE.put(k, null);
  },
};
