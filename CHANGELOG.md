# Changelog

Every push of app changes to `main` makes a new release on [GitHub Releases](https://github.com/armstrang/XueCi/releases)
(v1.0, v1.1, …). CI uses the `## v1.N` section below as the release notes for that version, so write the section
before pushing.

The Flutter app started again at v1.0 in October 2026. The earlier WebView app (v1.0–v1.17) and its changelog now
live in [armstrang/Merdeka-Mandarin](https://github.com/armstrang/Merdeka-Mandarin).

## v1.0 — October 2026

**XueCi starts again at 1.0 as a native app (Flutter) instead of a web page inside the app: the same app and the
same progress, every screen drawn natively, with a new look that is easier to read.**

### Your progress comes with you
- Install it over the previous version (the WebView app, up to 1.17) as usual. On the first start the app moves
  everything by itself: word progress, memory model, goal, realm and its history, tests, mock exams, meditation
  days, reminder, theme and language.
- To be extra safe, make a backup code in the previous version first (Settings › Backup › Back up) and keep it
  somewhere. Its codes restore in this version, and this version's codes work the same way.

### New look
- Glass all through: panels of soft milky glass that let a slow aurora of colour (your level's colour with warm
  and cool light) show through, a gentle glow along their edges and a bright rim where the light falls on them.
  The header buttons, the tab bar, menus and sheets are frosted glass over the page; the chosen tab, level and
  setting sit under a clear glass lens.
- Settings are grouped into one glass panel per section, like the phone's own settings; the realm guidance, the
  numbers on Stats and the answers in Quiz are glass inside glass.
- The space on Home goes above the realm orb; the realm line sits right above today's plan.
- Every text is checked for contrast against what is really behind it, on every main screen and sheet, in the
  light, dark and true-black themes (WCAG: 4.5:1, 3:1 for large text). Level, tone and element colours were
  darkened in the light theme where they were too pale to read.

### Changed
- Every screen is drawn natively instead of in a web page: Home, the word list, Cards, Quiz, the daily session, the
  HSK mock exam, Stats, the Soul Sea (its orb and the five-element ring), the realm sheet, the placement test and the
  tribulation with its lightning, Settings and the help guide. They work as before.
- Text follows the phone's text size, from small to very large, without breaking the layout.
- Backup codes are copied and pasted with the phone's own clipboard; sharing a code or the cultivation card uses the
  phone's share sheet.
- The learning engine (memory model, daily plan, question choice, realms, tests) is the same engine, rewritten and
  checked answer by answer against the previous version, so your plan and numbers stay the same.
- The list footer says that progress is saved on this device.

### Under the hood
- The app no longer runs inside a WebView. It still works fully offline and sends nothing anywhere.
