/// Anzahl Wörter je Lern-/Quiz-Batch (sequenzielle Freischaltung).
const int learnBatchSize = 10;

/// Anzahl frei spielbarer Lektionen zu Beginn **jedes** Sprachniveaus
/// (Rang 1–100, siehe [freeRanksPerLevel]). Der Rest des Sprachniveaus wird
/// durch einen einzigen In-App-Kauf ("Sprachniveau X komplett", siehe
/// `allLevels`) freigeschaltet (Nutzer-Vorgabe, 2. September 2026).
const int freeLessonsPerLevel = 10;

/// Anzahl frei verfügbarer Wörter zu Beginn jedes Sprachniveaus
/// (10 Lektionen × 10 Wörter = Rang 1–100).
int get freeRanksPerLevel => freeLessonsPerLevel * learnBatchSize;

/// Gruppennamen, in denen die arabische Transliteration (DIN 31635) angezeigt
/// wird — ab B1 bewusst nicht mehr (Nutzer-Entscheidung), da fortgeschrittene
/// Lerner die arabische Schrift direkt lesen sollen.
bool showsTransliteration(String group) => group == 'A1' || group == 'A2';

/// Das Sprachniveau, das [frequencyRank] enthält (Task H2, Offline-Wörterbuch
/// — zur Freischalt-Filterung eines Suchtreffers); `null`, wenn der Rang in
/// keinem Niveau liegt (z.B. ein Wort aus einer Gruppe ohne Level-Definition).
WordLevelInfo? levelForRank(int frequencyRank) {
  for (final level in allLevels) {
    if (frequencyRank >= level.startRank && frequencyRank <= level.endRank) {
      return level;
    }
  }
  return null;
}

/// Anzeige-Infos je Sprachniveau (A1, A2, B1, B2, …). Von Store- und Home-
/// Screen gemeinsam genutzt; ersetzt die frühere 100er-Wörter-Block-
/// Freischaltung (Task C3/C4) als Freischalt-Ebene (Nutzer-Vorgabe vom
/// 2. September 2026: Freischalt-Ebene ist wieder das Sprachniveau, nicht der
/// Block; die ersten [freeLessonsPerLevel] Lektionen jedes Niveaus sind frei).
class WordLevelInfo {
  const WordLevelInfo({
    required this.group,
    required this.startRank,
    required this.endRank,
    required this.label,
    required this.wordCount,
    required this.lessonsPerLevel,
    this.productId,
    this.planned = false,
  });

  final String group;
  final int startRank;
  final int endRank;
  final String label;
  final int wordCount;

  /// Lektionen/Batches dieses Sprachniveaus (Wörter ÷ [learnBatchSize]).
  final int lessonsPerLevel;

  /// Google-Play-/App-Store-Produkt-ID zum Freischalten des **restlichen**
  /// Niveaus (über die freien Einstiegs-Lektionen hinaus). Jedes Niveau ist
  /// grundsätzlich kaufbar.
  final String? productId;

  /// `true`, wenn das Niveau geplant, aber noch nicht als Inhalte hinterlegt
  /// ist (z.B. B1–C1). Solche Niveaus erscheinen als „Bald verfügbar“ und sind
  /// (noch) nicht spielbar; aktive Niveaus (A1/A2) sind vollständig spielbar.
  final bool planned;
}

/// Hero-Tag für die Titel-Übergangsanimation (Task E1) in der ganz-gruppen-
/// weiten Sicht (`BatchListScreen`). Lernen- und Quiz-Tab zeigen dasselbe
/// Niveau gleichzeitig (über `IndexedStack`) — ohne die Unterscheidung nach
/// Modus gäbe es zwei Heroes mit demselben Tag in derselben Route.
String groupTitleHeroTag(String group, {required bool isQuiz}) =>
    'group-title-${isQuiz ? 'quiz' : 'learn'}-$group';

/// Alias-Helfer für die Hero-Tag-Semantik pro Sprachniveau (deckt sich mit
/// [groupTitleHeroTag]; existiert zur Klarheit an den Aufrufstellen).
String levelTitleHeroTag(String group, {required bool isQuiz}) =>
    groupTitleHeroTag(group, isQuiz: isQuiz);

/// Regex-Zeichenklasse aller Harakat/Tashkil (Fatha, Damma, Kasra, Sukun,
/// Shadda, Tanwin = U+064B–U+0652, Alif-Khanjariyya = U+0670) — konsistent zur
/// bestehenden Python-Konvention (`scripts/prepare_words.py`, `HARAKAT_RE`).
/// WICHTIG: kein `r`-Raw-Präfix — sonst blieben `\u064B` die wörtlichen Zeichen
/// statt der echten Unicode-Codepunkte und der Regex würde nie matchen.
const String _harakatChars = '\u064B-\u0652\u0670';

/// Entfernt alle Harakat/Tashkil aus [text]. Wird für die diakritik-insensitive
/// arabische Wörterbuch-Suche genutzt: Die Wörter sind mit Harakat gespeichert
/// (z.B. `كَتَبَ`), typische Nutzer tippen aber ohne („كتب").
String stripHarakat(String text) =>
    text.replaceAll(RegExp('[$_harakatChars]'), '');

/// Normalisiert [text] für die Transliteration-Suche offline (nur innerhalb
/// der Wörterbuch-Suche; ändert nichts an den gespeicherten Daten/Anzeige).
/// Die wissenschaftliche DIN-31635-Umschrift der Wörter (z.B. `qaraʾa`,
/// `ḏahaba`, `ǧāʾa`) enthält Makron/Diakritika, die typische Nutzer nicht
/// tippen. Diese Funktion vereinheitlicht gängige, eintippbare Formen
/// (z.B. „kataba", „qaraa", „dahab") mit der gespeicherten Form.
String normalizeTransliterationForSearch(String text) {
  var s = text.toLowerCase();
  // Makron-Vokale -> Basisvokal
  s = s.replaceAll('ā', 'a').replaceAll('ī', 'i').replaceAll('ū', 'u');
  // Hamza/Ain (Zeichen, die oft weggelassen werden) -> entfernen
  s = s.replaceAll('ʾ', '').replaceAll('ʿ', '');
  // Digraph-/Dentale-Diakritika -> ASCII-Äquivalente
  s = s
      .replaceAll('ḏ', 'dh')
      .replaceAll('ṯ', 'th')
      .replaceAll('š', 'sh')
      .replaceAll('ǧ', 'j')
      .replaceAll('ḥ', 'h')
      .replaceAll('ṣ', 's')
      .replaceAll('ḍ', 'd')
      .replaceAll('ṭ', 't')
      .replaceAll('ẓ', 'z')
      .replaceAll('ġ', 'gh');
  return s;
}

/// Das Sprachniveau, das in der Stufen-Reihenfolge `allLevels`
/// (A1 → A2 → B1 → B2 → C1) direkt nach [group] kommt — also die **nächste
/// Stufe**, die bei Abschluss der aktuellen automatisch freigeschaltet wird
/// (Abschluss-Freischaltung statt Kauf, 10. September 2026). `null`, wenn
/// [group] das letzte Level ist oder nicht definiert ist.
WordLevelInfo? nextLevelAfter(String group) {
  for (var i = 0; i < allLevels.length; i++) {
    if (allLevels[i].group == group && i + 1 < allLevels.length) {
      return allLevels[i + 1];
    }
  }
  return null;
}

/// Die definierten Sprachniveaus. Aktiv sind **A1 und A2** (Wörter 1–1000,
/// je 50 Lektionen — Inhalte in `assets/data/` vollständig hinterlegt,
/// inkl. Satz-Audios für die Lektionen 1–100). B1–C1 sind geplant: sie
/// erscheinen auf der Startseite als „Bald verfügbar“ und sind noch nicht
/// als Inhalte hinterlegt (keine Wortdaten). Die Freischaltung der Stufen
/// erfolgt seit 10. September 2026 durch **Abschluss der vorherigen Stufe** —
/// es gibt keine Käufe mehr.
const List<WordLevelInfo> allLevels = [
  WordLevelInfo(
    group: 'A1',
    startRank: 1,
    endRank: 500,
    label: 'Grundstufe',
    wordCount: 500,
    lessonsPerLevel: 50,
    productId: 'jumlah_a1',
  ),
  WordLevelInfo(
    group: 'A2',
    startRank: 501,
    endRank: 1000,
    label: 'Sehr häufig',
    wordCount: 500,
    lessonsPerLevel: 50,
  ),
  WordLevelInfo(
    group: 'B1',
    startRank: 1001,
    endRank: 2000,
    label: 'Häufig',
    wordCount: 1000,
    lessonsPerLevel: 100,
  ),
  WordLevelInfo(
    group: 'B2',
    startRank: 2001,
    endRank: 3000,
    label: 'Mittel',
    wordCount: 1000,
    lessonsPerLevel: 100,
    planned: true,
  ),
  WordLevelInfo(
    group: 'C1',
    startRank: 3001,
    endRank: 5000,
    label: 'Selten / Klassisch',
    wordCount: 2000,
    lessonsPerLevel: 200,
    planned: true,
  ),
];
