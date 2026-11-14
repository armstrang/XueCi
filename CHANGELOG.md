# Changelog

Every push of app changes to `main` makes a new release on [GitHub Releases](https://github.com/armstrang/XueCi/releases)
(v1.0, v1.1, …). CI uses the `## v1.N` section below as the release notes for that version, so write the section
before pushing.

Test builds before a release are published as pre-releases v1.0-alpha-N.

## v1.2

**The music, made again: gentler on the ear.**

- The first music could be tiring to listen to. Every piece is new, after the calm music of the guqin and the xiao:
  one low, warm plucked zither and one low, breathy flute, never more than two voices, no beat, long silences
  between the phrases, nothing sharp or high, no bells, no glass, no big echo.
- Each piece is now 2 minutes 40 seconds long, so it no longer feels like a loop.
- Quieter: Soft, Medium and Loud are all lower than before. Off is still in Settings › Background music.

## v1.1

**Calm music for each realm, and a quiet living background.**

### Music
- Each realm has its own quiet piece, played on recorded instruments: a zither, a bamboo-like flute, bells, a soft
  gong and low strings. One short theme belongs to you; at each realm it goes a little further, and only at the top
  does it come home. Very slow, no drums, no build-ups: music to sit with, not to rush.
- On and soft by default. Settings › Background music: Off, Soft, Medium or Loud.
- The music steps back while a word is spoken, is silent while the app listens to you and during the HSK mock exam,
  and stays out of the way when another app is already playing music.

### A living background
- Slow motes of light and a thin mist drift behind every screen; your realm's orb breathes, one calm breath every six
  seconds.
- A right answer opens a soft golden glow; a wrong one leaves a thin ripple, like a drop on still water. Screens change
  with a light wash of ink.
- The tribulation no longer flashes lightning: each strike's sign rises softly and fades.
- With light visual effects, or with animations turned off on your phone, everything stands still.

## v1.0

**XueCi starts again at 1.0 as a native app (Flutter) instead of a web page inside the app: the same app and the
same progress, every screen drawn natively, with a new look that is easier to read.**

### Your progress comes with you
- Install it over the previous version (up to 1.17) as usual. On the first start the app moves
  everything by itself: word progress, memory model, goal, realm and its history, tests, mock exams, meditation
  days, reminder, theme and language.
- To be extra safe, make a backup code in the previous version first (Settings › Backup › Back up) and keep it
  somewhere. Its codes restore in this version, and this version's codes work the same way.

### Speaking practice
- A microphone next to each example sentence in the List, and a new quiz type, Speak: say the word or sentence and
  every hanzi turns green (right) or red (missed), with what the phone heard. Try again as often as you like.
- Tap the mic to start and tap again to stop (15 seconds at most; a ring counts down). You get a score from 0 to
  100 (Not yet, Getting there, Good, Perfect!), what you said, and each hanzi in green or red; tap a red one to
  hear it. The app listens itself, with no pop-up window. The mic breathes with
  your voice and shows what it hears as you speak. It asks once for the microphone; nothing is recorded or kept,
  only the recognized text is used. Strictness in Settings: Easy (tones may slip), Normal, Hard (only the phone's
  first guess).
- No Mandarin voice for the speaker yet? A short guide shows how to install one.

### A new icon
- Simpler: just 词, drawn as one clean line on seal red. With the phone in dark mode it turns night and gold (if
  your launcher follows the theme), and Android 13's themed icons show 词 alone in your wallpaper's colours.

### A new opening
- The app opens on its own background (no icon): a drop of gold ink, XueCi writing itself in letter by letter over
  a gold line, and Home rising in as the wordmark moves into its corner, in under two seconds. Tap to skip it. It
  plays only when the app starts fresh, follows your theme (light or dark), and is a short fade when the phone is
  set to remove animations.

### Cleaner, calmer screens
- Large titles with the level, unit and quiz type (as an icon) in glass pills under them; a tab bar with a name under every icon.
- Home: a small realm orb beside the realm's name and stages, then one big Today card with a single Start button,
  then word mastery.
- Quiz: the question alone in its card, the answers below where the thumb is (rows, or a 2×2 grid for hanzi and
  tones), a tick or cross on the answer and a light buzz, then one big Next.
- Cards: a bigger card and hanzi, bigger buttons. Swipe the card right for "I know it", left for "Don't know"; it
  tilts with your finger and springs back if you let go early. Sheets can be pulled down to close.
- Scroll a screen and its title moves into a small frosted bar at the top.
- Easier reading: bigger notes and explanations, long paragraphs aligned left, the breakthrough's strikes as clear
  rows with their score, the stats' bands in an even grid, and labels that never get cut off with large text (a
  shorter form appears instead). With visual effects on Low, sheets and bars are solid so nothing shows through.
- A tick or cross now springs onto the answer, with a light buzz when you were right; the Home percentage counts up
  as the app opens.
- Word mastery on Home is one calm line; tap it for the HSK lens and the counts.
- Tablets: Home sits in a centred column (upright) or two columns (landscape), with the HSK lens and the counts open.

### New look
- Glass all through: panels of soft milky glass that let a slow aurora of colour (your level's colour with warm
  and cool light) show through, a gentle glow along their edges and a bright rim where the light falls on them.
  The header buttons, the tab bar, menus and sheets are frosted glass over the page; the chosen tab, level and
  setting sit under a clear glass lens.
- Settings are grouped into one glass panel per section, like the phone's own settings; the realm guidance, the
  numbers on Stats and the answers in Quiz are glass inside glass.
- The space on Home goes above the realm orb; the realm line sits right above today's plan.
- Smoother: a new screen, card or question fades in on its own instead of being drawn on top of the old one; a
  button's spring redraws only the button; the frosted layers share one blur; shadows are drawn the cheap way; hidden
  meanings in the list are a soft bar instead of a blur; the Soul Sea opens several times faster; what the screens
  show from your progress is worked out once and reused until something changes; timers redraw only their clock.
- Little touches: the realm ring and the progress bars grow in, a right answer gives a small pop and a wrong one a
  short shake (with a buzz), and the word grid in Stats is drawn in one go, so it opens about twice as fast.
- Every text is checked for contrast against what is really behind it, on every main screen and sheet, in the
  light, dark and true-black themes (WCAG: 4.5:1, 3:1 for large text). Level, tone and element colours were
  darkened in the light theme where they were too pale to read.

### Changed
- The app's wording was rewritten to sound like a person, not a manual: shorter sentences, plain words, and
  explanations that say what to do (Indonesian and English first).
- Quiz: the Guided type and the Quick exam are gone (the HSK mock exam covers what the Quick exam did). Pick the
  type you want (Recognise is the default); today's session on Home still chooses the words and question types for
  you.
- The HSK mock exam was rebuilt after the new HSK 3.0 paper: the real number of questions per section, a clock for
  each section, and new kinds of question: hear a sentence and pick the word in it, its meaning, or whether a
  written sentence matches it (each sentence plays twice at most); put pieces in order to make a sentence; pick the
  character for the pinyin in brackets. HSK 1–2 show pinyin like the real paper. Choose the full paper or a short
  one (a third as long).
- Sentence gaps help by level: HSK 1–2 show the meaning and pinyin, HSK 3–4 the meaning, HSK 5 and up the sentence
  alone. Once a word is getting strong, the help fades. This help no longer costs the answer its credit; asking
  for the translation yourself still does. The placement test shows the meaning for HSK 1–4 too.
- After several misses in a row, a word you know well comes next, so a hard run doesn't turn into a losing streak.
- A "2′" button next to today's practice: about two minutes, six reviews, for days with little time.
- Thai and Vietnamese text rewritten to sound natural, like the Indonesian and English.
- About has a Licences section: the word list's MIT licence and the fonts' Open Font Licence.
- Terms of service, linked from About and Settings next to the privacy policy.
- 护法: an optional donation through Google Play (the coin next to Settings, and a quiet invitation once per realm after a breakthrough). It unlocks nothing; every feature stays free. Donors get a 护法 seal in the Soul Sea.
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
- The app is now fully native. It still works offline and has no server of its own: speaking practice uses your
  phone's speech recognizer, and only donations talk to Google Play.
