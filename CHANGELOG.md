# Changelog

Every push of app changes to `main` makes a new release on [GitHub Releases](https://github.com/armstrang/XueCi/releases)
(v1.0, v1.1, …). CI uses the `## v1.N` section below as the release notes for that version, so write the section
before pushing.

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
