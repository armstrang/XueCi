# XueCi Mandarin — project notes for Claude

HSK 1–6 vocabulary app (word list, flashcards, quiz, per-word mastery) by **Armstrang** (GitHub `armstrang`, goes by Josh).
Formerly "Merdeka Mandarin" (repo `armstrang/Merdeka-Mandarin`, no longer built). Josh writes in Indonesian: reply in Indonesian.
Goal right now: a proper **Google Play** release. The plan and open decisions are in `docs/play-store.md`.

## How it is built

The whole app is **one self-contained HTML page** shown in an Android WebView. No framework, no npm.

| Path | What |
|---|---|
| `web/src/base.css.html` | `<title>` + base layout styles |
| `web/src/app.html` | markup + all app logic; placeholders `__I18N__`, `__DATA__` |
| `web/src/i18n.js` | `const I18N={id,en,th,vi}` UI strings (more keys are added with `Object.assign` near the end of `app.html`) |
| `web/src/glass.css.html` | Liquid Glass look; injected right after the base `</style>` so it overrides it |
| `web/src/glass.js.html` | Liquid Glass interactions (HSK lens, screen zoom, theme reveal, haptics), appended at the end |
| `web/data/vocab.json` | 5,334 words, one per line. **Canonical data** — edit here |
| `web/build.py` | builds `app/src/main/assets/index.html` (committed; local fonts) and `web/dist/xueci-mandarin.html` (web copy, ignored; Google Fonts) |
| `web/make_fonts.py` | makes `app/src/main/assets/fonts/*.woff` (+ OFL licences), `web/fonts/fonts.css`, `web/fonts/charset.txt` from the original fonts (see its docstring for where to get them; `web/fonts/src/` is not committed). Chinese fonts are cut to the ~2,000 characters the app uses — **re-run after adding words**; `build.py` warns about missing characters |
| `app/` | single-module Android app, `MainActivity.java` only |
| `art/` | icon artwork: `icon-source.jpg` (from Josh, the 学词 badge); `python3 art/make_icons.py` regenerates `icon-badge.png`, every launcher mipmap, `play-icon-512.png`, `docs/privacy/icon.png` and `icon-preview.png` |
| `tests/smoke.py` | Playwright smoke test of the built page |
| `store/` | Play listing: `listing.md` (ID + EN texts and other Play Console answers), screenshots 1080×1920 and feature graphics 1024×500 per language; `python3 store/make_store_assets.py` regenerates them from the built app with sample progress (captions in the script). Re-run after visible UI changes |

After any change in `web/`: `python3 web/build.py && python3 tests/smoke.py`, then look at the screenshots in `tests/out/`.
The smoke test serves the assets over http (so fonts load), fails on any request leaving the app, and runs one case with text at 160%.

### Text size
Write font sizes in **px** in the sources. `build.py` rewrites every `font-size:Npx` to `calc(Npx*var(--fs,1))` (and `≥26px` or `clamp()` to `--fsd`).
The first script in `base.css.html` sets `--fs` from `MMAndroid.fontScale()` (the phone's text size, clamped 0.85–1.6; `?fs=1.3` in the URL for testing),
`--fsd = 1 + (fs−1)/2`, and adds `html.bigtext` from 1.15. Compact chrome that must not grow fully (header capsule title/chips, HSK pills, brand, tile
subtitles, stats scale labels) is written directly as `calc(Npx*var(--fsd,1))` — the rewrite leaves values starting with `calc(` alone. WebView `textZoom` stays 100.
CI also runs `web/build.py`, so a forgotten rebuild only matters for local Android Studio builds.

### Data fields (`vocab.json`)
`l` level 1–6 · `n` number in level · `u` unit · `h` hanzi · `p` pinyin · `s` pinyin per character (tone colours) ·
`z` example sentence · `m`/`t` meaning/sentence translation in Indonesian · `em`/`et` English · `vm`/`vt` Vietnamese · `hm`/`ht` Thai.
`M(d)` / `TR(d)` pick the meaning/translation for the current study language.

### App logic worth knowing (`app.html`)
- Screens: `#scr-home`, `#scr-focus` (`data-mode` = list / card / quiz), `#scr-stats`. `go(s)` → `window.mmTransition(run, from, to)` when defined.
- Mastery: `stats[id] = [right, wrong, level]`, `MAXL = 20`; right +1, wrong −3. Bands: 0–6 red, 7–13 yellow, 14–20 green; `.m0`–`.m20` colour classes.
- Hooks the glass layer defines: `mmTransition`, `mmHomeRendered(S)`, `mmStatsRendered()`, `mmFeedback(ok)`.
- `window.mmBack()` is called by Android's back button: closes info sheet → backup sheet → quiz menu → lang/level/unit menus → screen; returns `false` on Home (app exits).
- Progress backup (Home → Backup button beside tone info → Back up / Restore, `#bkSheet`): one line `XUECI1:` + base64url(deflate-raw(JSON {app:'xueci',v,at,stats,ui,lang,theme})) (`XUECI0:` = uncompressed). Restore finds the code inside any pasted text, validates every entry against `IDX`, shows a summary, then applies it in place (stats, level/unit, language, theme) — no reload (a write-then-reload can read stale localStorage). Native copy/share/paste go through `MMAndroid.copyText/shareText/pasteText`; in a browser it falls back to the Clipboard/Share APIs.
- Language: `langPref` = `auto` (follows the system: id/in/ms → id, th, vi, else en) or a code.
- Themes: `auto`, `light`, `dark`, `black` (`window.MM_THEMES`, set by `build.py`). `notifyNative()` sends CSS `--bar`/`--bar2` to `MMAndroid.setBars(top, bottom, dark)`.
- **localStorage keys hold users' progress — never rename them:** `mm_stats`, `mm_lang`, `hsk16_ui`, `hsk16_theme` (`hsk16_known` = legacy import).
- The WebView origin is `https://appassets.androidplatform.net` (WebViewAssetLoader). Changing it would also lose progress.

### Design rules (from Josh's feedback — he notices)
- Animations: transform/opacity only, ~200–300 ms. A 1 s morph + staggered entrance was rejected as slow and choppy.
- `backdrop-filter` only on layers that float over scrolling content (header capsule `.frow`, menus, sheet, toast, stats bar). The background is a static glow, so blurring static panels costs frames and shows nothing.
- No glow/light that follows the finger, no tilt effects.
- Focus header = one translucent capsule (back · title · HSK · unit) with flat controls inside; no glass-on-glass, no gradient band behind it.
- HSK selectors (Home and Stats) use the draggable glass lens from `glass.js.html` (`makeLens`).
- Menus are moved into `.fbar` by JS because a parent with `backdrop-filter` stops a child's own blur from seeing the page.
- Privacy policy: `docs/privacy/index.html` (ID + EN), served by GitHub Pages at https://armstrang.github.io/XueCi/privacy/ and linked from About (`.plink`). It describes exactly what the app does with data (on-device storage, Android backup, no internet use — fonts are bundled, INTERNET still declared but unused, VIBRATE). **Update it whenever data behaviour or permissions change.** Contact is GitHub Issues only — don't publish an email.
- The About section must not say who wrote the meanings/examples. (They were generated by Claude; the README says so.)
- Footer credit is "by Armstrang".

## Android
- `applicationId` / package **`com.armstrang.xueci`** (from v1.3 — the Play Store ID; it can never change once on Play).
  Up to v1.2 the app was `com.jorgi.merdekamandarin`; v1.2 is the last build of that ID and has Back up, so people can move their progress.
- `versionCode = 100 + GITHUB_RUN_NUMBER`, `versionName = 1.(run − 1)`.
- `compileSdk`/`targetSdk 36`, Android Gradle Plugin 8.13.2, Gradle 8.13. **Edge-to-edge**: `MainActivity` draws behind the system bars and puts two
  colour strips (`topBar`/`bottomBar`, heights from `WindowInsetsCompat` system bars + cutout; bottom = max(nav bar, keyboard)) around the WebView.
  `setBars` colours those strips and sets light/dark bar icons with `WindowInsetsControllerCompat` (window bar colours are ignored on Android 15+).
- Signing: `keystore/merdeka.jks` with the password in `app/build.gradle`. **This repo is public, so that key is exposed.** Fine for the sideload line only; the Play release needs a new upload key kept in GitHub Secrets.
- `MainActivity`: WebView + `WebViewAssetLoader`, JS bridge `MMAndroid` (`setTheme`, `setBars`, `fontScale`, `copyText`, `shareText`, `pasteText`), back button → `mmBack()`, outside links open in the browser, VIBRATE for haptics.

## CI (`.github/workflows/build-apk.yml`)
Push to `main` → `web/build.py` → `./gradlew assembleRelease` → GitHub release `v1.N` with `XueCiMandarin.apk` (marked latest).
Docs/art/tests-only changes do not trigger a build (`paths-ignore`); add `[skip ci]` to a commit message to skip one otherwise.
A guard step refuses to publish into an existing release tag.
`check.yml` compiles any `build/**` branch without publishing (its own run counter, so release numbers stay in sequence) — push Android changes there first, then fast-forward `main`. CI artifact zips can't be downloaded from Claude's cloud sessions (blob storage is blocked); release assets can.
In Claude's cloud sessions the GitHub proxy refuses API writes to releases/tags (HTTP 403), so let CI do the publishing.
