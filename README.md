# جُمْلَة · Jumlah — Arabic Learning App

> **Jumlah** (جُمْلَة) means "sentence" in Arabic — the smallest unit of understanding.

A Flutter app for learning **Classical Arabic (Fusha / Quranic Arabic)** —
offline-first, gamified, with context sentences for every word.

---

## 🎯 Project Goal

Learn Classical Arabic in a structured way — from the most frequent words to
rare Quranic expressions — with real sentence context instead of isolated
vocabulary.

---

## 📱 Platform

| Platform | Status |
|-----------|--------|
| Android   | 🚀 Primary target |
| iOS       | ⏳ After Android release |

---

## 🗂️ Word Groups

| Group | Words | Description |
|--------|--------|--------------|
| A1 | 500 | Most frequent words |
| A2 | 500 | Very frequent |
| B1 | 1,000 | Frequent |
| B2 | 1,000 | Intermediate |
| C1 | 2,000+ | Rare / Classical |

> **Note:** The app is **completely free** — all 500 A1 words are playable
> without any purchase. There is no store: all levels are shown directly on the
> home screen. The entry level A1 is always unlocked; each further level
> (A2–C1) is unlocked by **completing the previous level** (A2–C1 currently
> have no content yet and appear as „Soon available").

---

## 🧠 Learning Methodology

```
10 words per lesson (ordered by frequency A1–C1)
     ↓
3 context sentences per word (Arabic + German + transliteration)
     ↓
Word-by-word analysis (tap → expand)
     ↓
Root family + classical definition + masdar
  (modeled on Lane's Lexicon / hawramani.com)
     ↓
6-stage school exam (no instant feedback):
  1. Arabic → German
  2. German → Arabic
  3. Words alternating
  4. Sentences alternating
  5. Arabic audio → German option
  6. Short story → choose the matching translation
     ↓
Pass with max. 3 total errors → next lesson unlocked
```

> **Gamification:** A run counts as passed if **no more than 3 errors** were made
> in total („school exam"). More errors → complete restart. Sequential lesson
> unlocking: a lesson can only be played after passing the previous one (and in
> quiz mode, only if the lesson's learning path was completed beforehand).

**Dictionary approach (hybrid):** The learning path stays frequency-based (A1–C1),
but each word additionally shows its three-letter root family and a short
definition oriented on classical dictionaries (Lisān al-ʿArab, Lane's Lexicon,
etc., referenced via [arabiclexicon.hawramani.com](https://arabiclexicon.hawramani.com/))
— instead of a plain one-word translation.

---

## ✨ Features

- **Offline-first** — word lists, sentences, roots and sentence audio ship
  inside the app; progress is stored locally in SQLite.
- **6-stage school exam** quiz with audio and short-story reading phases.
- **Spaced repetition** review (SM-2) for due words.
- **Offline dictionary** with transliteration-friendly search.
- **Progress statistics** with activity heatmap and current streak.

---

## 🛠️ Tech Stack

| Component | Tool | Description |
|------------|------|--------------|
| Framework | Flutter (Dart) | null-safety, cross-platform |
| Database | SQLite (sqflite) | Offline-first, local |
| State | Riverpod | Reactive state management |
| Monetization | None | The app is completely free — no in-app purchases |
| Assets | JSON (offline) | Pre-generated word & sentence data |
| Sentence Gen | Python (validation) + AI-assisted (one-time) | No API key needed at runtime |

---

## 🎨 Design System

| Token | Color | Usage |
|-------|-------|------------|
| `primary` | `#1B6CA8` | Blue — primary color |
| `gold` | `#C9A84C` | Gold — highlights, gamification |
| `dark` | `#0D1117` | Background (dark mode default) |
| `success` | `#10B981` | Green — correct answer |
| `error` | `#EF4444` | Red — wrong answer |

**Fonts:** Amiri (Arabic) · Inter (German/UI)
**Mode:** Dark mode default

---

## 📁 Project Structure

```
jumlah/
├── assets/
│   ├── data/
│   │   ├── words.json          ← All words (500 in A1)
│   │   ├── sentences.json      ← Context sentences (1500)
│   │   └── roots.json          ← Root clusters, classical definitions
│   ├── audio/lektion_1…20/    ← Sentence audio (MP3)
│   ├── branding/jumla_logo.png ← App logo
│   └── fonts/
│       └── Amiri-Regular.ttf   ← Bundled Arabic font (SIL OFL 1.1)
├── lib/
│   ├── main.dart               ← Entry point (starts SplashScreen)
│   ├── core/                   ← Theme, database helper, audio service, widgets
│   ├── models/                 ← Word, Sentence, Progress, Root, QuizSession
│   ├── providers/              ← LearnProvider, QuizProvider, PurchaseProvider
│   └── screens/                ← home/, learn/, quiz/, dictionary/, info/, onboarding/, splash/
├── scripts/                    ← Content-generation pipeline (Python)
├── test/                       ← Unit & widget tests
└── pubspec.yaml
```

---

## 🚀 Quick Start

### Prerequisites
```bash
flutter --version   # Flutter 3.x+
python --version    # Python 3.10+ (only needed for content scripts)
```

### Run the app
```bash
# Install dependencies
flutter pub get

# Android (emulator or device)
flutter run

# Release build
flutter build apk --release
```

### Run the tests
```bash
flutter analyze
flutter test
```

### Prepare word data
```bash
python scripts/prepare_words.py
```

---

## 📊 Data Structure

### words.json
```json
{
  "id": 1,
  "arabic": "كَتَبَ",
  "german": "schreiben",
  "root": "ك-ت-ب",
  "group": "A1",
  "frequency_rank": 1
}
```

### roots.json (root family, hybrid approach)

```json
{
  "root": "ك-ت-ب",
  "classical_definition": "Grundbedeutung: schreiben, zusammenfügen, vorschreiben — nach Lisān al-ʿArab / Lane's Lexicon",
  "source": "hawramani.com Aggregation (Lisān al-ʿArab, Lane's Lexicon)",
  "related_word_ids": [1, 14, 87]
}
```

> Linked to `words.json` via `root`, so that every word in the learning path
> can show its classical root meaning.

### sentences.json
```json
{
  "word_id": 1,
  "arabic": "كَتَبَ الطَّالِبُ الدَّرْسَ",
  "german": "Der Student schrieb die Lektion.",
  "word_analysis": [
    { "word": "كَتَبَ", "translation": "schrieb" },
    { "word": "الطَّالِبُ", "translation": "der Student" },
    { "word": "الدَّرْسَ", "translation": "die Lektion" }
  ]
}
```

### SQLite – progress
```sql
CREATE TABLE progress (
  word_id       INTEGER PRIMARY KEY,
  level         INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  wrong_count   INTEGER DEFAULT 0,
  last_seen     TEXT
);
```

---

## 🔌 Provider API

| Provider | Methods |
|----------|----------|
| `LearnProvider` | `loadBatch(group, batchIndex)` · `nextWord()` · `prevWord()` · `toggleAnalysis()` |
| `QuizProvider` | `startQuiz(words)` · `startOrResumeQuiz(group, batchIndex)` · `submitAnswer(answer)` · `nextQuestion()` |
| `PurchaseProvider` | `isLevelUnlocked(group)` · `refresh()` |
| `DatabaseHelper` | `insertWords(list)` · `getWordsByGroup(group)` · `updateProgress(wordId, correct)` · `isLevelUnlocked(group)` · `unlockLevel(group)` |

---

## 📜 License & Attribution

The code and bundled content are **all rights reserved** — this repository is
published for viewing only; no license is granted to use, copy, modify or
redistribute it.

Third-party content included in this repository:

- **Amiri** (Arabic font) by Khaled Hosny — licensed under the SIL Open Font
  License 1.1 (`assets/fonts/Amiri-Regular.ttf`).
- Root definitions oriented on public-domain classical dictionaries
  (Lisān al-ʿArab, Lane's Lexicon), aggregated via
  [arabiclexicon.hawramani.com](https://arabiclexicon.hawramani.com/).
- Sentence audio files were automatically generated for the bundled lessons
  (see `scripts/`).