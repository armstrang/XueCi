# XueCi Mandarin — project notes for Claude

HSK 1–9 vocabulary app for Android (HSK 7–9 hidden until the gate opens, see *Realms*): word list, flashcards, quiz,
per-word mastery, a goal-driven daily plan. By **Armstrang** (GitHub `armstrang`, goes by Josh). Formerly "Merdeka
Mandarin". Josh writes in Indonesian: **reply in Indonesian**. Goal: a proper **Google Play** release; plan and open
decisions in `docs/play-store.md`.

The app is **Flutter** (Dart, `mobile/`). It is in testing as **1.0-alpha** (pre-releases `v1.0-alpha-N`). The earlier
WebView version was removed from this repo (archived in `armstrang/Merdeka-Mandarin`; don't bring it back).

## Layout

| Path | What |
|---|---|
| `content/vocab.json` | the words (one per line), canonical: edit here |
| `content/i18n/` | interface text: `base.js` (`I18N`, helper `r`), `id.js`, `en.js`, `th.js`, `vi.js` — **each key defined once per language**; strings, or arrow functions for text with numbers. Text past the gate sits between `/*<seal>*/ … /*</seal>*/` at the end of each file |
| `content/tools/` | `sentence_pinyin.py` (field `zp`), `word_freq.py` (fields `f`, `g`) |
| `mobile/lib/engine/` | `learn.dart` = `LM` (FSRS, plan, questions, realms, tests, optimizer…), `fsrs.dart`, `model.dart` (Mem, LogE, Item…), `js.dart` (exact helpers: `jsRound`, `jsSort`, LCG random, `jsJson`) |
| `mobile/lib/data/` | `store.dart` (progress store, one file per key in `files/store`, schema + migrations), `words.dart`, `pinyin.dart`, `seal.dart` |
| `mobile/lib/i18n/` | `l10.dart` + generated `keys.g.dart`; text functions are expression trees (`tool/make_i18n.js`, acorn) evaluated by `Tpl`; only `<b>` markup (`Rich`) |
| `mobile/lib/app/` | `app.dart` (`App`: boot, language, theme, fx, realm helpers, reminder/rest sync, backup timing, widget, `memo`), `runner.dart` (Cards/Quiz/session/mock runs), `backup.dart` (XUECI1/XUECI0 codes), `native.dart` (method channel), `mastery.dart` |
| `mobile/lib/ui/` | `shell.dart` (MaterialApp, background, tab bar, toasts, back), `home.dart`, `focus.dart` (capsule header, list, menus), `run_view.dart` (cards, questions, summary, mock), `stats.dart`, `soul.dart`, `realm.dart`, `tests.dart` (placement, tribulation, gate ceremony), `settings.dart`, `goal.dart`, `backup_sheet.dart`, `info.dart`, `share.dart`, `fx.dart`, look: `glass.dart`/`theme.dart`/`lens.dart`/`widgets.dart`/`icons.dart`/`sheet.dart`/`word_ui.dart`, `screens.dart` (screen hosts, `wireSheets()`) |
| `mobile/tool/` | `make_assets.py` (needs `npm install --prefix mobile/tool acorn@8.15.0`): `assets/data` (core + per-language words, sealed `s0.bin`/`s-<lang>.bin`) and `assets/i18n`; refuses public text with a secret word. `make_fonts.py` (font subsets; re-run after new characters; sources in `fonts-src/`, not committed). `cloud_sdk.sh` (Flutter SDK for Claude's cloud sessions) |
| `mobile/android/` | Kotlin: `MainActivity.kt` (method channel `xueci/native`), `Reminder.kt` (+ `ReminderReceiver`), `XueciWidget.kt`; `assets/legacy.html` (progress move) |
| `mobile/test/` | `engine_trace_test` (replays `fixtures/engine/*.json` call by call; a deliberate engine change = update the fixture with care), `i18n_test`, `store_test`, `backup_test`, `secret_test`, `contrast_test`, `screens_test` (screenshots → `test/goldens/`, not committed: look at them), `perf_probe_test` (`PERF=1`) |
| `art/` | icon artwork; `python3 art/make_icons.py` writes every icon into `mobile/android` |
| `store/listing.md`, `docs/privacy/` | Play listing text; privacy policy (GitHub Pages) |

In Claude's cloud sessions: `. /opt/flutter-env.sh`, then in `mobile/`: `FLUTTER_ROOT=/opt/flutter dart pub get --offline`,
`flutter analyze --no-pub`, `flutter test --no-pub [--update-goldens]`. No Android SDK here: Kotlin is compiled by CI only.
After a change: `python3 mobile/tool/make_assets.py` (if `content/` changed) → analyze → tests → look at the screenshots.

## Rules

- **Progress keys never change** (users' data): `mm_stats`, `mm_lang`, `hsk16_ui`, `hsk16_theme`, `hsk16_known`, `xc_mem`,
  `xc_log`, `xc_logA`, `xc_goal`, `xc_w`, `xc_fit`, `xc_onb`, `xc_lvl` (+ `th`, `pt`, `gate`, `gs`, `stab`, `hist`),
  `xc_rem`, `xc_tests`, `xc_rest`, `xc_game`, `xc_amb`, `xc_note`, `xc_schema`, `xc_days`, `xc_bk`, `xc_res`, `xc_fx`,
  `xc_fxd`, `xc_mock`, `xc_legacy`; Android SharedPreferences `reminder`, `widget`. Schema `xc_schema` = 3; a data format
  change = a new migration + schema + a test in `store_test`; migrations never delete keys.
- **Moving progress from the earlier version** (first start): `App.boot` asks `Native.legacy()` when the store has no
  `xc_schema`; `MainActivity` opens a hidden WebView on the old origin `https://appassets.androidplatform.net`
  (`assets/legacy.html`) and returns its IndexedDB `xueci/kv` (or localStorage). On failure (8 s) it answers `!`,
  `xc_legacy` = 1 and the next start tries again (adopting the old data while fewer than 30 words were practised).
  **Never delete that WebView data or change the origin.**
- **The secret** (Josh: HSK 7–9 must be a real surprise): before the gate nothing may hint at more — no realm after 飞升,
  no help/glossary rows about it, no 译 strike, nothing in CHANGELOG, README, listing or privacy policy. Secret words:
  真仙 玄仙 大罗 仙门 'HSK 7' 'HSK 8' 'HSK 9' '7–9' '7-9' xiānmén zhēnxiān xuánxiān dàluó. Text that names them goes in a
  seal block; `make_assets.py` seals it (deflate + xoshiro128** keystream seeded by SHA-256 of `'天外有天|'` + all HSK 6
  hanzi + `'|'` + file name; each file starts with a short readable header and a zero byte). `secret_test` enforces it.
- **App text sounds human** (Josh, Oct 2026: "masih sangat AI"): short sentences, "kamu", concrete words; no stacked
  colons, no "model memori/klaim/ulangan berjarak" jargon; say what to do, not how the algorithm works. Indonesian first.
- Package **`com.armstrang.xueci`** never changes. `versionCode`: release 2000 + run, test builds 1000 + run (the earlier
  version used 100 + run). Signing: `keystore/xueci.jks` (alias `merdeka`, same certificate as the earlier version so
  updates install over it; public, so test builds only). The Play bundle uses the upload key from the secrets
  `XC_UPLOAD_*` when `XC_PLAY=1`; Josh creates that key himself.
- Privacy policy (`docs/privacy/index.html`, ID + EN): update it whenever data behaviour or permissions change. Contact
  is GitHub Issues only — never publish an email. About never says who wrote the meanings/examples (README does).
  "by Armstrang" only in About. About → Licences shows `mobile/assets/legal/licenses.txt` (hsk30 MIT + the fonts' OFL):
  keep it when fonts or data sources change.
- CHANGELOG is in English; the `## v1.N` section is the release text.

## Look and motion (Josh notices)

- **Glass** (Josh: Samsung Galaxy "Fluid AI" glass + Apple Liquid Glass; the earlier flat cards looked cheap):
  `paintGlass()` in `glass.dart` is the one material — milky fill (`Pal.glassA/B`, `innerA/B`), light from the top left
  (`sheen`), a white glow inside the edge (top-weighted on dark), a rim bright along the top with a glint at the
  bottom-right. Kinds: `GK.panel`, `GK.inner` (inside a panel/sheet: `GlassDepth`), `GK.frost` (floating, real blur),
  `GK.lens` (chosen tab/level/segment: `TabLens`, `HskLens`, `LensPill`). `GlassFlat` = grouped rows in one glass
  (`SGroup`). Background `_BgPainter` = aurora (level tone + `auroraWarm` + `auroraCool`). Shadows only outside shapes
  (`OuterShadow`). `contrast_test` (WCAG 4.5:1, large text 3:1, light/dark/black) must stay at 0 findings: tune `Pal`
  against it (`CDUMP=1` writes the measured images to `test/cdump/`).
- **Motion**: transform/opacity only, 200–300 ms; a 1 s morph with staggered entrances was rejected. No light that
  follows the finger, no tilt. Screen and question switches show only the incoming view (`reverseDuration: Duration.zero`,
  `layoutBuilder` = current) in a `RepaintBoundary`; `Press` springs inside its own boundary.
- **Smoothness**: blur only on floating layers (tab bar, header capsule, sheets, menus, toasts), grouped with
  `BackdropGroup` + `BackdropFilter.grouped` (σ 16); shadows of rounded rectangles are analytic (`drawRRect` with a mask
  blur), never a blurred path; `paintGlass(rr:)` takes the RRect fast paths. Engine views go through `app.memo(key, f)`
  (kept while `Store.ver` and the minute are unchanged). Clocks redraw themselves, not the app. No `dynamic` in hot loops.
- Home must fit one screen (360×680 up) and keeps its order: header pills (wordmark, cultivation days, Settings) → the
  realm orb flowing into one panel (realm line, stage bars, today's plan) → word mastery with the HSK lens → tab bar.
  Don't add rows to Home without taking space elsewhere. Text follows the phone's size (clamped 0.85–1.6; compact chrome
  uses `Compact`, half-way).
- Tab bar: Home/List/Cards/Quiz/Stats (Soul Sea, flame icon), icons only except the open tab, a glass lens that can be
  dragged; hidden in session/placement/tribulation, while typing and in exams.
- HSK lens (Josh: clear, "murim"): clear glass tinted by the level, the realm's colour glowing inside, a faint ring of
  the five elements, a thin gold line on top; the chosen number takes the level colour.
- Focus header = one translucent capsule (back · title · HSK · unit), no glass on glass.

## How the app works

- **Words**: fields `l` level · `n` number · `u` unit · `h` hanzi · `p` pinyin · `s` pinyin per character · `z` example
  sentence · `zp` its pinyin (word in `{}`) · `m`/`t` Indonesian meaning/translation · `em`/`et` English · `vm`/`vt`
  Vietnamese · `hm`/`ht` Thai · `f` Zipf frequency · `g` jieba part of speech. Re-run `sentence_pinyin.py` after editing
  any `z` or pinyin. Hand-fixed pinyin: 目的 mùdì, 充分 chōngfèn, 更换 gēnghuàn, 尽力 jìnlì, 牛仔裤 niúzǎikù, 适当 shìdàng,
  水分 shuǐfèn, 挑战 tiǎozhàn, 相册 xiàngcè, 行业 hángyè, 背包 bēibāo. Sentence pinyin reads HSK 1–6 sentences with HSK 1–6
  words only; `NOT_BEFORE` and `FIXED` cover the rest; 的 alone is de, 周一 is yī.
- **Engine `LM`**: FSRS-5 with one state per word (`w`, drives schedule and level) and per skill (`m` meaning, `f`
  form/recall + sentence, `s` sound/tones + listening). Level = round(20·ln(1+S)/ln 121), capped at 13 until `f` and
  `s` were passed. `LM.answer(...)` is the only way answers are recorded. `plan(goal)`, `session()`, `cardDeck()`,
  `quizRound()`, `mockExam()`, `question(d, q)` (look-alike distractors). `optimize()` fits the parameters to the
  learner's reviews (≥100, pulled towards the defaults), at most daily. `modelCheck()` shows predicted vs real recall.
  Mastery bands: 0–6 red, 7–13 yellow, 14–20 green; **solid** = level ≥10 + passed `f` and `s`.
- **Runs** (`runner.dart`): Cards, Quiz and the session share one `Run` of items. Cards: "Don't know" / "I know it" →
  adaptive quick check → back side; "I was wrong" undoes an unchecked claim. Quiz types `m`, `f`, `s`, `l`, `c`, `p`
  (typed pinyin: tone numbers or marks, ü as v, same-meaning words accepted), `t` (sentence → translation, multiple
  choice), `mock`. Guided and the Quick exam were removed (Josh); a saved `auto`/`exam` falls back to `m`.
  Wrong items come back 4 items later (max twice). **Sentence-gap help by level** (Josh: beginners give up or cheat;
  change how questions are asked, never the word lists): HSK 1–2 meaning + pinyin, 3–4 meaning, ≥5 the sentence
  alone (`clozeAid` in `run_view.dart`); in practice the help fades as the word gets strong (pinyin off from level 7,
  meaning from 14); tests keep the level's help (placement counts helped gaps as easier, `itemB`); this help keeps
  full credit, *Show translation* = no skill credit; *My choice fits too* (3/day) undoes and marks the pair. After
  misses (<70 % of the last 8), a well-known word comes next (`_ease`, ≤4 per run, not in tests). **2′** on Home =
  six of today's reviews (`quickOf`).
- **Realms** (Josh's cultivator idea): 凡人 (0, untested), 炼气 筑基 金丹 元婴 化神 渡劫 (1–6 = HSK 1–6), 飞升 (7). Only
  tests change the realm. Stages 初期/中期/后期/圆满 = progress <25/25–50/50–80/≥80 %, progress = (solid words + ½ × the
  placement estimate for the rest) ÷ the level's words. One test a week (placement or breakthrough); leaving after 10
  answers counts. Placement: 50 adaptive questions with "Don't know", sets the realm once (at most 渡劫; one retake
  within 14 days). Breakthrough = 雷劫 tribulation: strikes 识 m ×5, 忆 p ×5, 听 l ×5 (skipped without TTS), 读 c ×5,
  速 m ×8 timed; pass = every strike ≥70 % and total ≥ 75 % (80 % from HSK 5). Grade 道基: 完美 no mistake, 上品, 中品,
  下品; placement realms are 认定. Stability: a realm rests on the level below; fading (spaced answers <70 % or recall
  <0.6) makes it 境界不稳 until a 试炼稳固 (15 words, 80 %). Guidance (`advice()`), forecast, breakthrough chance.
- **The gate** (sealed): a breakthrough to 飞升 opens 仙门 (`xc_lvl.gate`), loads the sealed band (HSK 7–9, realms 8–10),
  shows the ceremony once (`gs`); a 飞升 from placement gets a make-up tribulation on HSK 6 first. A restored backup
  keeps the gate only with a real breakthrough and ≥50 % of HSK 6 words stable.
- **Soul Sea** (Stats tab): the orb (≤900 words, lines between words sharing a character, brightness = recall, colour =
  level; spins, slows to a stop), the five-element ring (土 root = realm progress, 木 cult = memory days, 水 sense =
  recall now, 金 dao = "I know it" that held up, 火 insight = days to solid; segments fill clockwise along 木→火→土→金→水;
  weakest = dashed, strongest = filled + title), today's trial, cultivation days (meditation days and one free day a
  week keep the streak), rest numbers, realm history, the cultivation card (1080×1350 PNG, shared via the phone).
- **Rest**: one 调息 break offer per sitting (accuracy drop, slowing, or 25 min) with a breathing guide; meditation days
  (0–2 weekdays: no plan, reminder quiet, reviews pulled a day earlier); late-night note; welcome back after ≥2 days.
- **HSK mock exam** (Josh: like the real exam; the **HSK 3.0** paper): `LM.mockPaper` = questions and minutes per
  section (听力/阅读/书写; HSK 1 has no writing; HSK 5–6 essays are replaced by sentence building), full or short (⅓,
  `mks` in `hsk16_ui`). Each section has its own clock, starting at its intro; time up = the rest of it unanswered.
  Kinds: `l`, `ls` (word heard in a sentence), `lj` (same/different: a written sentence, maybe with one word swapped),
  `lt` (meaning heard), `m`, `c`, `t`, `wo` (pieces in order; cut by the sentence's pinyin, `LM.pieces`), `wh`
  (hanzi for the pinyin in brackets, sound-alike options). Sentences play twice at most; HSK 1–2 print pinyin. The
  log keeps them as `l`/`f`/`c` (`LM.logQ`). No feedback until the end; each section /100, pass 60 % (HSK 3.0 marks
  unpublished), every question reviewed, advice with practice buttons; history in `xc_mock` (+1 = short).
- **Backup**: one line `XUECI1:` + base64url(deflate-raw(JSON)) (`XUECI0:` uncompressed) with progress, memory states,
  goal, fitted parameters, realm, rest days, tests, mock history and study days (not the answer log). Restore finds the
  code in any pasted text, checks every entry, shows a summary, applies in place. A quiet dot on Settings when ≥30 words
  were practised and there's no backup in 30 days.
- **Reminder** (Android): time and text from the goal sheet; quiet once practised that day or on a meditation day;
  re-armed after reboot/update/time change. **Widget**: realm, stage, today's practice, cultivation days, fed by
  `App.syncWidget` only when something changed.
- **Visual effects** setting: auto/low/full; auto steps down once if frames are slow (toast). Low = no blur, no glow.
- **First start**: a 3-step tour ending in the goal sheet; a new learner sees two ways in (start from zero / placement).
- **Easter egg**: seven taps on the wordmark → a seal stamps 天外有天 (封 before the gate, 开 after).
- Pronunciation uses the phone's TTS (zh-CN, rate 0.9); polyphonic characters are guessed by the engine.

## CI

- **Work happens on `main`** (only branch). `.github/workflows/flutter.yml` (every push): assets → analyze → tests → APK;
  its output (summary, logs, screenshots, `xueci-dev.apk`) goes to branch `ci-out/main`
  (`git fetch origin "+refs/heads/ci-out/main:refs/remotes/origin/ci-out/main"`). When everything passes, the APK is
  published as pre-release **`v1.0-alpha-N`** (N = highest + 1, versionName 1.0.0-alpha.N, `XueCiMandarin-alpha.apk`,
  never latest; the first was plain `v1.0-alpha`). `[skip ci]` in a commit message = no build, no alpha.
- `.github/workflows/build-apk.yml`: the official release, **run by hand only** when Josh says so (APK + Play bundle,
  release `v1.N`, notes from `CHANGELOG.md`; refuses an existing tag).
- `.github/workflows/flutter-sdk.yml` (by hand): the `dev-flutter-sdk` pre-release for Claude's cloud sessions; delete
  it after the first release when Josh agrees.
- From Claude's cloud sessions the GitHub proxy refuses deleting releases, tags and branches and API writes to releases
  (HTTP 403), and GraphQL; let CI do it (a one-off workflow on a throwaway branch, only when Josh asks). CI artifact zips
  can't be downloaded here; release assets and branches can.
