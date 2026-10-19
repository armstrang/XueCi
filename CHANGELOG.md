# Changelog

Every push of app changes to `main` makes a new release on [GitHub Releases](https://github.com/armstrang/XueCi/releases)
(v1.0 … v1.17, then v2.0, v2.1, …). CI uses the `## vX.N` section below as the release notes for that version, so
write the section before pushing.

## v2.0 — October 2026

**XueCi is rebuilt as a native app (Flutter) instead of a web page inside the app: the same app and the same
progress, with every screen drawn natively.**

### Your progress comes with you
- Install v2.0 over v1.x as usual. On the first start the app moves everything from v1.x by itself: word progress,
  memory model, goal, realm and its history, tests, mock exams, meditation days, reminder, theme and language.
- To be extra safe, make a backup code in v1.x first (Settings › Backup › Back up) and keep it somewhere. Codes made
  by v1.x restore in v2.0, and v2.0's codes work the same way.

### Changed
- Every screen is drawn natively instead of in a web page: Home, the word list, Cards, Quiz, the daily session, the
  HSK mock exam, Stats, the Soul Sea (its orb and the five-element ring), the realm sheet, the placement test and the
  tribulation with its lightning, Settings and the help guide. They look as before, with small refinements.
- Text follows the phone's text size, from small to very large, without breaking the layout.
- Backup codes are copied and pasted with the phone's own clipboard; sharing a code or the cultivation card uses the
  phone's share sheet.
- The learning engine (memory model, daily plan, question choice, realms, tests) is the same engine, rewritten and
  checked answer by answer against v1.x, so your plan and numbers stay the same.
- The list footer says that progress is saved on this device.

### Under the hood
- The app no longer runs inside a WebView. It still works fully offline and sends nothing anywhere.

## v1.17 — 19 October 2026

**A new icon, an HSK mock exam that marks itself and tells you what to practise, and a home-screen widget.**

### New
- **HSK mock exam** (Quiz › HSK mock exam). Laid out like the HSK: listening, reading and, from HSK 3, writing
  (pick the hanzi for a meaning, type the pinyin from memory), each part opened by its own card, one clock for the
  whole exam and no marking until the end. Then everything is corrected at once: a score out of 100 for each part,
  the total against the pass mark (120 of 200 for HSK 1–2, 180 of 300 from HSK 3), every question with your answer
  and the right one, and advice drawn from your mistakes (your weakest part, sentence gaps, tones, older words,
  time) with buttons that practise exactly the words you missed. Your mock exams are kept, so you can see the trend.
  If the phone has no Chinese voice, the listening part is left out and the score comes from the other parts.
- **Home-screen widget**: your realm, its stage and progress, today's plan and your cultivation days. Tap it to open
  the app.
- **New app icon**: 学词 with a sword, a star and a golden arc. On Android 13 and later it can follow your wallpaper
  colours (themed icons), and the splash screen shows it too.

### Changed
- The 20-question timed exam is now called **Quick exam**.
- While a mock exam is running, the tab bar and the level pickers step aside, and the first press of Back only warns.

## v1.16 — 19 October 2026

**A smaller tab bar with a glass lens you can slide and the Soul Sea one tap away, an HSK picker in clear glass with
the colours of your realm and the five elements, lightning in the tribulation, a cultivation card to share, and a
layout for tablets.**

### New
- **Tab bar, smaller and with the Soul Sea.** Home, Word list, Cards, Quiz and **Stats** (the Soul Sea, with a
  cultivation-flame icon). The tabs show only their icon; the open one also shows its name. A glass lens sits under
  the open tab: slide it along the bar and let go on a tab to open it.
- **Cultivation card.** A picture of your realm, its ring, stage, cultivation days, solid words and words practised,
  to share with any app. Open it with the share button at the top of the Soul Sea, or after a successful
  breakthrough. It is made on your phone and goes only to the app you pick.
- **Lightning in the tribulation (雷劫).** Every strike opens with a bolt of lightning and its seal character; a
  passed tribulation ends in golden light. With reduced motion turned on, only a soft fade.
- **Tablets and wide windows.** Home in two columns (your realm on the left, word mastery with its counts on the
  right); the Soul Sea keeps its orb on the left while its cards scroll on the right.
- A small secret for the curious.

### Changed
- **HSK picker.** The lens over the chosen level is now clear glass instead of a solid pill: tinted with the level's
  colour, glowing with your realm's colour inside, with a rim that runs through the five elements (木 火 土 金 水).
- On tall phones the realm panel no longer stretches with empty space inside; the room goes around the panels.
- Word-mastery counts no longer run into each other in longer languages.
- The app page is about 15% smaller and starts a little faster.

## v1.15 — 19 October 2026

**A tab bar that stays put, a Home that always fits the screen, a splash screen, clearer colours, and full visual
effects with slowly drifting light.**

### New
- **Tab bar.** Home, Word list, Cards and Quiz now sit in a glass bar at the bottom that stays on every screen, like
  a music app. Tap the tab you are on to jump back to the top. It steps aside during a session, a test, a
  breakthrough, while the keyboard is open and while a menu is open.
- **Splash screen.** The app shows its logo in the theme colour while it starts, instead of an empty screen.
- **Full visual effects** now have soft light that drifts slowly behind the glass. It settles after 10 seconds
  without a touch and sleeps while the app is in the background or during a session or test, so it costs little
  battery. Automatic and Light are unchanged.

### Changed
- **Home fits one screen on every phone and at every text size.** The realm orb grows and shrinks with the room
  left, and smaller lines step aside on short screens or with large text, instead of the page running off the
  bottom.
- **Easier to read:** grey text, tone colours and labels have more contrast in light, dark and black themes;
  small links have bigger touch areas; every button has a name for TalkBack.

### For the Play Store
- Each release now also carries an Android App Bundle (`XueCiMandarin.aab`) for Google Play.

## v1.14 — 19 October 2026

**A new Home in fluid glass with your realm in the middle, Settings in one place, cultivation days in the header, a
clear start for new learners, and display modes that keep the app smooth on any phone.**

### New
- **New Home.** Your realm is a glass orb in the middle: its name, pinyin and a ring that fills with your progress
  in the current stage. It flows into one glass panel with the realm's meaning, a plain sentence about where you are,
  the four stages, and today's practice. Below it: word mastery with the HSK picker, and a bar with Word list,
  Cards and Quiz. Tap the orb for the Soul Sea and the realm path; "?" explains what a realm is.
- **Settings** (gear, top right): theme, visual effects, study language, goal and meditation days and reminder,
  backup, research data, a short tour, tones and help, and the privacy policy. The language and theme buttons and
  the backup and tone buttons moved here, so Home has room to breathe.
- **Cultivation days in the header**: an incense stick with the number of days, lit once you have practised today.
  Tap it for a five-week calendar of practice and meditation days and your longest run.
- **A clear start for new learners**: "Start from zero" or "Studied before? Take the placement test", and a short
  three-step tour on first start (also in Settings).
- **Visual effects: Automatic, Light or Full.** Automatic matches the phone: slower phones (and phones with data
  saver or reduced transparency) get lighter glass, a lighter Soul Sea and no glow. If screens still run slowly on
  automatic, the app steps down once by itself and says so.

### Changed
- The word list paints its first words at once and the rest in small steps, so opening it never stalls.
- The backup reminder dot now shows on the Settings button.

### Fixed
- Long sheets (realm, help, goal), the unit menu and long card backs no longer show a stray line with square corners
  while scrolling.
- Restoring a backup code checks the realm data in it more strictly.

## v1.13 — 19 October 2026

**The breakthrough becomes a tribulation in strikes, realms have a foundation quality and can become unstable, the
placement test is the way in, typed pinyin and translation questions, model accuracy in Stats, and a design pass.**

### New
- **The breakthrough is a lightning tribulation (雷劫 léijié)**: a series of strikes, each one skill on your realm's
  words, with no feedback until the end:
  - 识 meaning · 忆 pinyin typed from memory · 听 listening (left out if the phone has no Chinese voice) ·
    读 the word that fits a sentence · 速 meanings against the clock (6 seconds a question for HSK 1–3, 5 for HSK 4–6).
  - It is passed when **every strike** has at least 70% right **and** the whole reaches the cut (75%, 80% from
    HSK 5). Luck in one strike can't carry a weak skill.
  - The result shows every strike with its score.
- **Foundation quality (道基 dàojī).** The margin of a passed tribulation sets the quality of the new realm:
  下品 low, 中品 middle, 上品 high, or 完美 perfect with not a single mistake. It shows in the realm path and the
  realm history.
- **Unstable realm (境界不稳).** A realm rests on the level below it. If those words fade (under 70% right in spaced
  reviews over 30 days, or the memory model expects you to recall under 60% of them), the realm becomes unstable and
  the breakthrough waits until you pass a **stabilising trial (试炼稳固)**: the 15 most faded words, 80% right.
  A realm never drops.
- **Typed pinyin questions** (meaning → type the pinyin with its tones). Tone numbers (xue2sheng1) or tone marks
  both work, ü can be typed as v, the neutral tone needs no number, and 一 and 不 accept their spoken tones. A word
  with the same meaning counts as right.
- **Translation questions** (a whole sentence → choose its translation). The other options are sentences of about
  the same length, so they have to be read.
- **Model accuracy in Stats**: every spaced review is replayed through the memory model, and the recall it predicted
  is compared with what happened, in five bands. Folded into one line by default.
- **Research data (optional)**: you can copy your answer history, realm history and, if you like, your official HSK
  result as one code, to help check whether the realms match real HSK results. The app sends nothing; you copy or
  share the code yourself.

### Changed
- **The placement test is the way in.** It sets your starting realm once, at most 渡劫. One retake is allowed within
  14 days of the first test (in case it went wrong); its result replaces the first. After that the realm rises only
  by breaking through, one realm at a time. Realms reached by the placement test are marked 认定 rèndìng.
- If your 飞升 came from a placement test (before v1.13), a make-up tribulation (补劫) on HSK 6 confirms it.
- **The memory model adapts to you sooner**: from 100 spaced reviews instead of 400, with a pull towards the default
  settings that fades as more of your answers come in.
- **Design pass**:
  - Home fills the screen exactly on every phone size: on taller phones the progress card grows (the ring sits
    above the legend on very tall ones) and the tiles move down into thumb reach; on short screens the tile
    subtitles step aside so nothing scrolls.
  - With large phone text, the progress card stacks ring over legend and nothing runs off the edge.
  - The tribulation intro keeps its rules in one quiet box; strike results have aligned bars.
  - The realm sheet no longer repeats the realm's name under the path; the realm history is in neat columns.
  - Stats are shorter: model accuracy is folded, and the model's state is said once.
  - Shorter pinyin placeholder, muted "not enough data" values.
- **Performance**: long word lists only lay out the cards near the screen, and bars no longer animate their width.
- **Sentence pinyin**: ties in word splitting now follow jieba's word boundaries and counts, which fixes about 50
  sentences (早上去 zǎoshang qù, 火车站 huǒchē zhàn, 获得了 huòdé le, 主要是 zhǔyào shì, 特别的 tèbié de …);
  周一 reads yī, and 的 on its own always reads de.

### Fixed
- After a stabilising trial, only answers given after it count towards stability.

## v1.12 — 18 October 2026

**Progress in a versioned IndexedDB store, word data out of the page, the placement test counted in realm progress,
measured elements and a five-element ring.**

### New
- **The placement test counts toward realm progress.** The test ends with an estimate of your ability, and from it
  each word of your realm's level gets a chance that you already know it (the same model the test uses, including
  how common the word is and whether its characters are new).
  - That estimate counts **half** toward the stage until practice proves a word solid; then the word counts fully.
  - A word you answer wrong loses its test credit.
  - The stage bar shows solid words in the realm colour and the test's share as a lighter, striped layer, with the
    number of words the test credited.
  - A placement test taken in v1.9–v1.11 counts too: its six level shares are turned back into an ability estimate.
  - A passed breakthrough moves the estimate up to the level it proved.
- **The five elements are a thick ring** around the soul orb instead of small leaves. Each segment fills clockwise
  from its element towards the next, along the generating cycle 木→火→土→金→水, so the ring only closes when every
  element is full. The value is written on each segment.
- **Backup**:
  - Backup codes carry your study days, so the cultivation days survive a restore.
  - The backup sheet says when the last backup was made.
  - After a month without one, or with real progress and no backup yet, a small dot shows on the Backup button.
    There is no notification.

### Changed
- **The five elements need evidence to rise.** Each one is now a count against a fixed scale, so none fills up from
  a few answers:
  - **水 神识 spirit sense**: the words of your realm's level you would recall right now. Before, it was the average
    recall of the words you had studied, which was near 100% after one session.
  - **金 道心 dao heart**: every "I know it" claim is checked, either at once or by your next answer to that word
    within 14 days, over the last 90 days. 20 neutral claims are added (half right), so 10 right claims give 67,
    40 give 83 and 100 give 92. Before, 5 right claims gave 100.
  - **火 悟性 insight**: needs at least 10 solid words.
  - Each element row shows the counts behind its value.
- **Progress is stored in IndexedDB** with a numbered schema (version 3) and ordered migrations:
  - From v1.7 data: two-number records get a level, and the oldest known-words list is imported.
  - From v1.8–v1.11 data: moved over unchanged.
  - Every change is still copied to localStorage as a safety copy.
  - If IndexedDB can't be used, the app works on localStorage as before.
  - Key names are unchanged, so nothing is lost.
- **The word list is no longer inside the page.** `data/core.json` holds hanzi, pinyin, examples and levels, and one
  file per language holds the meanings. Only the study language loads at start; the others load when chosen.
- **The code is split** into one file per screen or feature, formatted with Prettier, and dead code and unused texts
  were removed. Behaviour is unchanged.
- **Tests run in CI**: the browser smoke test (every screen, five sizes, themes and languages, migrations from older
  versions) and new engine tests in Node (store migrations, memory model, placement test, realm progress, elements,
  breakthrough, backup days). An APK is only built and published when both pass.

## v1.11 — 17 October 2026

**v1.10 rebuilt: realms explained one by one, visible realm progress, guidance on what to improve, and a smoother
Sea of Consciousness.**

### New
- **Realm progress you can see**:
  - The realm chip has a small ring that fills up to 圆满.
  - The realm sheet and the Sea of Consciousness show the **path of the eight realms** (tap any realm to read its
    hanzi, pinyin, meaning and HSK level).
  - A **stage bar** with 初期 chūqī · 中期 zhōngqī · 后期 hòuqī · 圆满 yuánmǎn, the percent to 圆满 and the solid words
    still needed.
  - An **estimate** of when you reach the next stage and 圆满, from your pace over the last 14 days.
  - At 圆满, the **chance to pass a breakthrough** now, worked out from how well you remember the level's words.
  - Before the placement test the same bar shows your preparation for 炼气.
- **Master's guidance (指点 zhǐdiǎn)**: a ranked list of what to improve, worked out from your memory model, each with a
  button to practise it straight away:
  - words one right answer away from solid (a missing Recall or Tones pass);
  - due words;
  - your weakest skill;
  - young words, with how many days they need on average (from simulating the memory model);
  - words not introduced yet;
  - words you often mix up;
  - how reliable your "I know it" is.
  The top two also appear in the realm sheet.
- **Help explains every term one by one**: tables of the eight realms and four stages (hanzi, pinyin, meaning,
  what it stands for), the five elements, and a new glossary of cultivation terms (突破 tūpò, 识海 shíhǎi, 闭关 bìguān,
  调息 tiáoxī, …). The Sea of Consciousness shows pinyin beside every heading and element.

### Fixed
- The 木 badge at the top of the five-element wheel was cut off. Every badge now sits inside the picture.
- Small values drew flat, clipped-looking leaves. Each leaf now has a dashed outline of its full size, and the
  filled leaf grows from the orb with the value.
- The weakest element is marked with a dashed badge instead of a blinking leaf, and the strongest with a filled one.

### Smoother
- The soul orb draws about 5× faster: a handful of draw calls per frame instead of more than a thousand, and nothing
  allocated per frame.
- The orb starts moving only after the screen has opened, pauses when scrolled out of view, keeps a flick's spin and
  slows down gently, and eases to a stop after 10 seconds.
- Cards further down the Sea of Consciousness are drawn only when you scroll near them.

## v1.10 — 17 October 2026

**Cultivation realms, the Sea of Consciousness, and rest as part of learning.**

### New
- **Realms (境界)** replace the plain level. Your realm is set only by a test: 凡人 *Mortal* (not tested yet) →
  炼气 *Qi Refining* (HSK 1) → 筑基 *Foundation Establishment* (HSK 2) → 金丹 *Golden Core* (HSK 3) → 元婴 *Nascent Soul*
  (HSK 4) → 化神 *Spirit Transformation* (HSK 5) → 渡劫 *Tribulation Crossing* (HSK 6) → 飞升 *Ascension* (HSK 6
  mastered). The meaning is shown in your study language. The chip beside the language button shows your realm.
- **Stages** inside a realm follow the share of *solid* words at that level (level 10+ with a passed Recall and Tones
  question): 初期 under 25%, 中期 25–50%, 后期 50–80%, 圆满 80% and up.
- **Breakthrough (突破)**: at 圆满 you can try for the next realm. 20 questions on the level's words with no feedback
  until the end, passed with 75% right (80% for HSK 5–6). If it fails, you see the words to strengthen and can practise
  them straight away.
- **One test a week**: the placement test and the breakthrough share one test every 7 days, counted from the last
  one. Leaving a test after 10 answers still counts.
- **Sea of Consciousness (识海)**: tap the realm chip → *See more*. A soul orb drawn from your own word memory (one point
  per word, lines between words that share a character, brightness = how well you remember it now, colour = HSK
  level; turn it with a finger, tap a point to see the word), with a core that changes with your realm. Around it the
  **five elements (五行)**: 土 Foundation (solid words at your realm), 木 Cultivation (days of memory stored), 水 Spirit
  Sense (recall right now), 金 Dao Heart (how often "I know it" was right) and 火 Insight (how fast new words become
  solid). The weakest element gets advice, the strongest gives you a title. The page also has your breakthrough
  progress, today's trial, cultivation days, the numbers behind rest, and your realm history.
- **Today's trial (今日试炼)**: one target a day for your weakest skill over the last 7 days, a little above your own
  level. A chip on the Today card shows the progress. No random rewards, no countdowns.
- **Cultivation days (修炼天数)**: days of practice in a row. Meditation days and one free day a week don't break it.
- **Rest is part of learning**:
  - A **调息 break** is offered (never forced) when your accuracy drops, your answers slow down, or you have practised for
    25 minutes. It has a 5-minute breathing guide, and the summary afterwards shows how you did after the break.
  - **Meditation days (闭关)**: choose 0–2 days a week in the goal sheet. No plan and no reminder on those days, and
    reviews due then are pulled one day earlier.
  - After extra practice, the summary shows from your memory model how little repeating the same words now adds
    compared with tomorrow after sleep. After 11 pm there is one note a night about sleep.
  - Coming back after two or more days off shows how much you still remember.
- **Help guide** in the help & info sheet: nine topics (daily plan, cards, quiz, word levels, realms, Sea of
  Consciousness, rest, backup, sound & display) in all four languages.

### Changed
- **The manual level pick is gone**: realms come only from tests. A level picked by hand in v1.9 keeps steering your
  daily plan until you take a test.
- **Sentence questions** hide the translation until you answer (it was a giveaway). HSK 1–3 sentences show their
  pinyin with the gap. *Show translation* is still there as a hint, but a hinted answer doesn't raise your skill levels.
  If your wrong pick also fits the sentence, *My choice fits too* (up to 3 times a day) takes the answer back and never
  offers those two words together again. Gap options now prefer words of the same word class.
- **Cards come in random order** (interleaving), and two look-alike words are never shown one after the other. Which
  words go in is still the memory model's choice.
- **Word difficulty**: each word's difficulty within its level now comes from how common it is in written Chinese
  (word frequencies from the open-source jieba dictionary) and whether it brings new characters. It shapes the first
  memory estimate, the order of new words and the placement test.
- Extra practice no longer repeats words you already reviewed today.
- The backup code also carries your meditation days and test dates.

### Privacy
- New data, all kept on the phone: the dates of your tests, your meditation days, today's trial and the number of
  trials done, sentence-word pairs you reported as both fitting, and which once-a-day notes were shown. Android gets
  your meditation days so the reminder stays quiet on them. The
  [privacy policy](https://armstrang.github.io/XueCi/privacy/) is updated.

## v1.9 — 16 October 2026

**Placement test, a current level, daily study reminders, and a Home screen that fits on one screen.**

### New
- **Placement test**: 50 quick questions that adapt to your answers, with a **Don't know** button so you don't have
  to guess. The questions come from a selected bank of words that bring characters new at their level, so they
  can't be worked out from easier words. HSK 5–6 only get the hard question types (recall the hanzi among look-alike
  options, tones, fill the gap in a sentence). To be placed at HSK 5 or 6 the test has to be 90% sure, and you need
  at least 5 questions of that level with 70% right. Lucky guesses don't count for much: the test estimates how
  often you guess and allows for it. The result shows your level and an estimate of how many words of each level
  you know.
- **Current level** beside the language button. It is HSK 1 by default; the placement test or your own pick sets
  it, and it moves up by itself once every word of the level has been introduced. It only steers the daily plan:
  words below your level are skipped there, and every level stays open in List, Cards and Quiz.
- **Daily study reminder** (Android): one notification a day at the time you choose (7 pm by default), in your
  study language, with today's estimated minutes. It stays quiet on days you have already practised. Set it in the
  goal sheet. Android 13 and newer ask for the notification permission first; the reminder is set again after
  the phone restarts.

### Changed
- **Home fits on one screen** on most phones: a compact plan card with the start button beside today's numbers,
  a progress ring that follows the screen height, and smaller tiles. The "all levels" line moved to the HSK menu.
- **New wordmark**: *XueCi* (with *Ci* in the level colour) over a spaced-out *MANDARIN*. "by Armstrang" left the
  header; the credit stays in About (the tone colours & info sheet).
- On first start the goal sheet suggests the placement test, and a goal set right after the test starts at your
  new level. A goal below your level counts as reached.
- Quiz: a wrong option can no longer have a meaning that contains the right one (or the other way round), so each
  question has exactly one right answer.
- The changelog and the GitHub release notes are now in English.

### Privacy
- Two new permissions: **notifications** (only for the reminder) and **run at startup** (only to set the reminder
  again after a restart). The reminder time and text stay on the phone. The
  [privacy policy](https://armstrang.github.io/XueCi/privacy/) is updated.

## v1.8 — 16 October 2026

**Guided learning.** The app builds a daily plan from your goal, checks every "I know it", and picks questions
for your weak spots. Everything is worked out on the phone; no data is sent anywhere.

### New
- **Study goal**: *Reach a level* (for example HSK 3 by a date), *HSK exam*, or *No target*, plus a daily amount in
  minutes or new words (or automatic). The app works out straight away whether the target is realistic and offers
  fixes if it isn't: more minutes, more words a day, or a later date. Asked once on first start (can be skipped)
  and changeable any time from Home.
- **"Today" plan on Home**: today's reviews and new words, estimated minutes, status (*on track* or *behind*), and
  a **Start session** button.
- **Today's session**: reviews of the words you are most likely to forget, new words (introduced as cards) and
  confirmations of old green words, mixed in one session. Wrong answers come back a few questions later. After days
  off the plan is rebuilt without a pile of overdue work. **Extra practice** afterwards.
- **Cards reworked**: *Don't know* or *I know it*. "I know it" has to be proven with a quick check (pick the right
  meaning or pinyin) before the card flips. Being sure but wrong counts more than honestly not knowing. The check is
  adaptive: learners who prove honest are checked less often, and after an unchecked claim there is an
  **I was wrong** button.
- **Guided quiz** (default): the app picks the words and question types for your weak spots. Five question types
  in steps: *Recognise* (hanzi → meaning), *Recall* (meaning → hanzi), *Tones* (pick the right pinyin), *Listen*
  (sound → hanzi; only when a Chinese voice is installed) and *Sentence* (fill the gap). Options get more alike as a
  word is better known, to keep you at about 80–85% right. A round is 12 questions with a summary. Every type can
  also be chosen by hand.
- **Exam practice**: 20 mixed questions from HSK 1 up to the chosen level in 5 minutes, scored with lucky guesses
  taken into account.
- **Learning insights** on Stats: recall right now, answers in the last 7 days, how often "I know it" was right,
  accuracy per question type (the weakest is marked and practised more), and words you mix up. Tap a word to see
  its meaning, hanzi and tone levels and when it comes back.
- **FSRS memory model** (open source) decides when each word is due. After 400 spaced reviews its parameters are
  fitted to how you remember, on the phone.

### Changed
- **Level 0–20 means something new**: how long you are expected to keep remembering the word (about a month =
  green, four months = 20). Repeating a word many times on the same day can no longer make it green, and green also
  needs a passed *Recall* and *Tones* question.
- **Earlier progress is kept**: every word keeps its level. Green words are marked *needs confirming* and get a short
  check (Recall and Tones) in the next sessions.
- The **Know it / Not yet** buttons on Stats are gone, because they gave levels without proof.
- The **backup code** also carries the memory model, the goal and the fitted parameters (not the answer history).
  Codes from earlier versions still restore.
- New subtitles for the Cards and Quiz tiles.

### Privacy
- The answer history (word, time, question type, right/wrong, wrong option picked, time taken) and the study goal
  are kept **on the phone only**. The history can be deleted with **Stats → Delete answer history**; word progress
  stays. The privacy policy is updated.

## v1.7 — 15 October 2026
- Pinyin for every example sentence, with the learned word highlighted. The pinyin is read in context, including the
  tone changes of 一/不, 得/地/着, measure words and erhua; names are capitalised.
- Pinyin fixed for 11 words: 目的 mùdì, 充分 chōngfèn, 更换 gēnghuàn, 尽力 jìnlì, 牛仔裤 niúzǎikù, 适当 shìdàng,
  水分 shuǐfèn, 挑战 tiǎozhàn, 相册 xiàngcè, 行业 hángyè, 背包 bēibāo.

## v1.6 — 15 October 2026
- Pronunciation test: speaker buttons in Cards, List and Quiz for the word and the example sentence, using the
  phone's own text-to-speech engine. If no Chinese voice is installed, the app opens the TTS settings.

## v1.5 — 15 October 2026
- Fonts are bundled in the app (Plus Jakarta Sans, Noto Sans/Serif SC, Noto Sans Thai), so the app no longer uses
  the internet.
- Text size follows the phone's setting (85–160%). Large hanzi and compact controls grow half as much so the layout
  stays tidy.

## v1.4 — 15 October 2026
- The **Backup** button moved to Home, beside the tone colours button.
- New 学词 icon.

## v1.3 — 15 October 2026
- Targets Android 16 (API 36) with an edge-to-edge layout: the status and navigation bars follow the theme and move
  up with the keyboard.
- New package name `com.armstrang.xueci` for Google Play, so the app installs separately. Move your progress from
  the old app with **Backup → Restore**.

## v1.2 — 15 October 2026
- **Back up and restore progress** as one text code to copy or share. This is the last version with the old package
  name (`com.jorgi.merdekamandarin`).

## v1.1 — 15 October 2026
- Privacy policy (Indonesian and English), linked from About.

## v1.0 — 15 October 2026
- New name **XueCi Mandarin** (formerly Merdeka Mandarin) in a new repository.
- Only the Liquid Glass version is kept, and version numbers start again at 1.0.
