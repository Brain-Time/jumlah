/// Konstanten zum Abspielen der vorab generierten Satz-Audiodateien
/// (`assets/audio/lektion_N/…`). Müssen zu `lib/core/word_groups.dart`
/// (`learnBatchSize`) und zum Generierungsskript (`scripts/test_first_10.py`)
/// passen.
///
/// Eine Lektion (Batch) umfasst *sentencesPerLesson* Wörter, wobei jedes Wort
/// *sentencesPerWord* Kontext-Sätze besitzt. Die Audio-Dateien einer Lektion
/// werden von `scripts/test_first_10.py` in Dateireihenfolge fortlaufend
/// nummeriert, d.h. das erste Wort belegt 1..3, das zweite 4..6 usw.
const int sentencesPerLesson = 10;
const int sentencesPerWord = 3;