import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/progress.dart';
import '../../models/quiz_session.dart';
import '../../models/root.dart';
import '../../models/sentence.dart';
import '../../models/word.dart';
import '../spaced_repetition.dart' show Sm2, Sm2ReviewItem, Sm2State;
import '../word_groups.dart'
    show allLevels, learnBatchSize, normalizeTransliterationForSearch,
        stripHarakat;

/// Kennzahlen der Lernstatistik (Task: Heatmap/Streak): aktuelle Serie
/// (`currentStreak`), längste bisherige Serie (`bestStreak`), Anzahl aktiver
/// Tage (`activeDays`) und die Interaktionen von heute (`todayCount`).
class StudyStats {
  const StudyStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.activeDays,
    required this.todayCount,
  });

  final int currentStreak;
  final int bestStreak;
  final int activeDays;
  final int todayCount;
}

/// Detaillierte Aktivität eines einzelnen Tages (aus `study_activity`).
class StudyDayActivity {
  const StudyDayActivity({
    required this.activityCount,
    required this.wordsViewed,
    required this.quizAnswers,
    required this.lessonsCompleted,
  });

  final int activityCount;
  final int wordsViewed;
  final int quizAnswers;
  final int lessonsCompleted;
}

/// Gesamtüberblick für den Statistik-Tab: Kennzahlen ([StudyStats]), die
/// Aktivität je Tag im gewählten Zeitfenster (`'YYYY-MM-DD' -> Interaktionen`)
/// und die heutige Detailaktivität ([StudyDayActivity]).
class StudyOverview {
  const StudyOverview({
    required this.stats,
    required this.activityByDate,
    required this.today,
  });

  final StudyStats stats;
  final Map<String, int> activityByDate;
  final StudyDayActivity today;
}

/// SQLite-Zugriffsschicht (Singleton). Schema und Zugriffsmethoden für
/// `words` und `progress` (Task B2) sowie `purchases` (Task C3 — persistiert
/// freigeschaltete Sprachniveaus, `group_name`; seit der Rückführung vom
/// 100er-Wörter-Block- auf das Sprachniveau-Modell).
/// `sentences`/`roots` kommen mit der Import-Pipeline in Task D1 dazu.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String databaseName = 'jumlah.db';
  static const int databaseVersion = 13;

  /// Versionsnummer der gebündelten Asset-Daten (`words`/`sentences`/
  /// `roots.json` — Task D1, Versions-Check). Unabhängig von
  /// [databaseVersion] (das ist das SQL-Schema): manuell hochzählen, sobald
  /// sich der *Inhalt* dieser drei Assets ändert (z.B. neue Wörter), damit
  /// [reimportAssetDataIfVersionChanged] bei bestehenden Installationen
  /// neu importiert statt die alten Daten dauerhaft zu behalten. Setzt
  /// voraus, dass neue Wörter stets ans Ende angehängt werden (siehe
  /// `prepare_words.py`) — nur dann bleiben Word-IDs stabil und
  /// bestehender Fortschritt (`progress`/`batch_progress`/...) bleibt
  /// korrekt zugeordnet.
  static const int dataAssetVersion = 17;

  static const String tableWords = 'words';
  static const String tableProgress = 'progress';
  static const String tablePurchases = 'purchases';
  static const String tableBatchProgress = 'batch_progress';
  static const String tableLearnProgress = 'learn_progress';
  static const String tableLearnPosition = 'learn_position';
  static const String tableQuizSession = 'quiz_session';
  static const String tableSentences = 'sentences';
  static const String tableRoots = 'roots';
  static const String tableMetadata = 'metadata';
  static const String tableStudyActivity = 'study_activity';
  static const String tableSm2State = 'sm2_state';

  static const String _dataAssetVersionKey = 'data_asset_version';
  static const String _deviceIdKey = 'device_id';
  static const String _onboardingSeenKey = 'onboarding_seen';

  Database? _database;

  Future<Database> get database async {
    return _database ??= await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, databaseName);
    return openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableWords (
        id INTEGER PRIMARY KEY,
        arabic TEXT NOT NULL,
        german TEXT NOT NULL,
        root TEXT NOT NULL,
        "group" TEXT NOT NULL,
        frequency_rank INTEGER NOT NULL,
        transliteration TEXT NOT NULL DEFAULT '',
        masdar TEXT NOT NULL DEFAULT '',
        masdar_transliteration TEXT NOT NULL DEFAULT '',
        masdar_german TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableProgress (
        word_id INTEGER PRIMARY KEY,
        level INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        last_seen TEXT,
        FOREIGN KEY (word_id) REFERENCES $tableWords (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tablePurchases (
        group_name TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableBatchProgress (
        group_name TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        passed_at TEXT NOT NULL,
        PRIMARY KEY (group_name, batch_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableLearnProgress (
        group_name TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        PRIMARY KEY (group_name, batch_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableLearnPosition (
        group_name TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        current_index INTEGER NOT NULL,
        PRIMARY KEY (group_name, batch_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableQuizSession (
        group_name TEXT NOT NULL,
        batch_index INTEGER NOT NULL,
        stage TEXT NOT NULL,
        attempts TEXT NOT NULL,
        stage_resolved TEXT NOT NULL,
        final_wrong TEXT NOT NULL,
        correct_count INTEGER NOT NULL,
        wrong_count INTEGER NOT NULL,
        PRIMARY KEY (group_name, batch_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableSentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        arabic TEXT NOT NULL,
        german TEXT NOT NULL,
        transliteration TEXT NOT NULL DEFAULT '',
        word_analysis TEXT NOT NULL,
        target_index INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sentences_word_id ON $tableSentences (word_id)',
    );
    await db.execute('''
      CREATE TABLE $tableRoots (
        root TEXT PRIMARY KEY,
        classical_definition TEXT NOT NULL,
        source TEXT NOT NULL,
        related_word_ids TEXT NOT NULL,
        example_noun_arabic TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableMetadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableStudyActivity (
        date TEXT PRIMARY KEY,
        activity_count INTEGER NOT NULL DEFAULT 0,
        words_viewed INTEGER NOT NULL DEFAULT 0,
        quiz_answers INTEGER NOT NULL DEFAULT 0,
        lessons_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableSm2State (
        word_id INTEGER PRIMARY KEY,
        repetitions INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        due_date TEXT NOT NULL,
        last_quality INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (word_id) REFERENCES $tableWords (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $tableWords ADD COLUMN transliteration TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('''
        CREATE TABLE $tableBatchProgress (
          group_name TEXT NOT NULL,
          batch_index INTEGER NOT NULL,
          passed_at TEXT NOT NULL,
          PRIMARY KEY (group_name, batch_index)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $tableLearnProgress (
          group_name TEXT NOT NULL,
          batch_index INTEGER NOT NULL,
          completed_at TEXT NOT NULL,
          PRIMARY KEY (group_name, batch_index)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE $tableQuizSession (
          group_name TEXT NOT NULL,
          batch_index INTEGER NOT NULL,
          stage TEXT NOT NULL,
          attempts TEXT NOT NULL,
          stage_resolved TEXT NOT NULL,
          final_wrong TEXT NOT NULL,
          correct_count INTEGER NOT NULL,
          wrong_count INTEGER NOT NULL,
          PRIMARY KEY (group_name, batch_index)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE $tableSentences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER NOT NULL,
          arabic TEXT NOT NULL,
          german TEXT NOT NULL,
          transliteration TEXT NOT NULL DEFAULT '',
          word_analysis TEXT NOT NULL,
          target_index INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_sentences_word_id ON $tableSentences (word_id)',
      );
      await db.execute('''
        CREATE TABLE $tableRoots (
          root TEXT PRIMARY KEY,
          classical_definition TEXT NOT NULL,
          source TEXT NOT NULL,
          related_word_ids TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE $tableMetadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE $tableRoots ADD COLUMN example_noun_arabic TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        "ALTER TABLE $tableWords ADD COLUMN masdar TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $tableWords ADD COLUMN masdar_transliteration TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $tableWords ADD COLUMN masdar_german TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE $tableLearnPosition (
          group_name TEXT NOT NULL,
          batch_index INTEGER NOT NULL,
          current_index INTEGER NOT NULL,
          PRIMARY KEY (group_name, batch_index)
        )
      ''');
    }
    if (oldVersion < 10) {
      // 100er-Wörter-Block-Umbau (Monetarisierung): die `purchases`-Tabelle
      // speicherte bislang gruppenbasierte Freischaltungen (`group_name`),
      // z.B. 'A2'. Kaufbar ist jetzt jeder 100er-Block über seinen
      // `block_index`. Alte Gruppen-Einträge sind wertlos (A1 war ohnehin
      // kostenlos, A2–C1 ohne Inhalte) und werden über die DROP+CREATE-
      // Migration verworfen; echte Käufe sind reine Non-Consumables und
      // lassen sich jederzeit über `restorePurchases` wiederherstellen.
      await db.execute('DROP TABLE IF EXISTS $tablePurchases');
      await db.execute('''
        CREATE TABLE $tablePurchases (
          block_index INTEGER PRIMARY KEY
        )
      ''');
    }
    if (oldVersion < 11) {
      // Rückführung auf Sprachniveau-Freischaltung (Nutzer-Vorgabe,
      // 2. September 2026): die `purchases`-Tabelle speicherte zwischenzeitlich
      // je 100er-Block (`block_index`). Freischalt-Ebene ist wieder das
      // Sprachniveau (A1, A2, B1, …) — gespeichert als `group_name`. Alte
      // Block-Einträge sind wertlos und werden über die DROP+CREATE-Migration
      // verworfen; echte Käufe sind reine Non-Consumables und lassen sich
      // jederzeit über `restorePurchases` wiederherstellen.
      await db.execute('DROP TABLE IF EXISTS $tablePurchases');
      await db.execute('''
        CREATE TABLE $tablePurchases (
          group_name TEXT PRIMARY KEY
        )
      ''');
    }
    if (oldVersion < 12) {
      // Lernstatistiken (Task: Heatmap/Streak): pro lokatem Datum wird die
      // Lern-/Quiz-Aktivität gezählt (`study_activity`) — Grundlage für
      // Streak- und Heatmap-Anzeige im neuen Statistik-Tab.
      await db.execute('''
        CREATE TABLE $tableStudyActivity (
          date TEXT PRIMARY KEY,
          activity_count INTEGER NOT NULL DEFAULT 0,
          words_viewed INTEGER NOT NULL DEFAULT 0,
          quiz_answers INTEGER NOT NULL DEFAULT 0,
          lessons_completed INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 13) {
      // Spaced Repetition (Task: SM-2): Wiederholungs-Pool je Wort.
      // `repetitions`/`ease_factor`/`interval_days` folgen dem SM-2-
      // Algorithmus (`lib/core/spaced_repetition.dart`); `due_date` ist der
      // lokale Tag (`'YYYY-MM-DD'`), ab dem das Wort wieder abgefragt wird.
      await db.execute('''
        CREATE TABLE $tableSm2State (
          word_id INTEGER PRIMARY KEY,
          repetitions INTEGER NOT NULL DEFAULT 0,
          ease_factor REAL NOT NULL DEFAULT 2.5,
          interval_days INTEGER NOT NULL DEFAULT 0,
          due_date TEXT NOT NULL,
          last_quality INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  Future<void> insertWords(List<Word> words) async {
    final db = await database;
    final batch = db.batch();
    for (final word in words) {
      batch.insert(
        tableWords,
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Lädt und parst eine JSON-Asset-Liste (Task D1, Fehlerbehandlung).
  /// Bei fehlender/korrupter Datei (kaputtes JSON, unerwartete Struktur)
  /// wird der Fehler geloggt und eine leere Liste zurückgegeben, statt den
  /// kompletten App-Start abstürzen zu lassen — die betroffene Tabelle
  /// bleibt dann schlicht leer, statt die App unbenutzbar zu machen.
  Future<List<T>> _decodeAssetList<T>(
    String assetPath,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint(
        'DatabaseHelper: Konnte $assetPath nicht laden/parsen ($error) — '
        'Tabelle bleibt leer.',
      );
      return const [];
    }
  }

  /// Importiert `assets/data/words.json` in die `words`-Tabelle, sofern
  /// diese noch leer ist (einmaliger Import beim ersten App-Start). Minimale
  /// Vorstufe von Task D1 — `sentences`/`roots` werden weiterhin direkt aus
  /// den Assets gelesen (siehe [learn_provider.dart]), nicht über SQLite.
  Future<void> importWordsIfNeeded() async {
    final db = await database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableWords',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    if (count > 0) {
      return;
    }
    final words = await _decodeAssetList(
      'assets/data/words.json',
      Word.fromJson,
    );
    await insertWords(words);
  }

  /// Importiert `assets/data/sentences.json` in die `sentences`-Tabelle,
  /// sofern diese noch leer ist (Task D1 — analog zu [importWordsIfNeeded]).
  Future<void> importSentencesIfNeeded() async {
    final db = await database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableSentences',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    if (count > 0) {
      return;
    }
    final sentences = await _decodeAssetList(
      'assets/data/sentences.json',
      Sentence.fromJson,
    );
    final batch = db.batch();
    for (final sentence in sentences) {
      batch.insert(tableSentences, sentence.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// Importiert `assets/data/roots.json` in die `roots`-Tabelle, sofern
  /// diese noch leer ist (Task D1 — analog zu [importWordsIfNeeded]).
  Future<void> importRootsIfNeeded() async {
    final db = await database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableRoots',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    if (count > 0) {
      return;
    }
    final roots = await _decodeAssetList(
      'assets/data/roots.json',
      WordRoot.fromJson,
    );
    final batch = db.batch();
    for (final root in roots) {
      batch.insert(
        tableRoots,
        root.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Gelesene, zuletzt importierte Asset-Version (`null`, wenn noch nie
  /// gespeichert — z.B. Erststart oder Upgrade von vor Task D1).
  Future<int?> getStoredDataAssetVersion() async {
    final db = await database;
    final rows = await db.query(
      tableMetadata,
      where: 'key = ?',
      whereArgs: [_dataAssetVersionKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return int.tryParse(rows.first['value'] as String);
  }

  Future<void> _setStoredDataAssetVersion(int version) async {
    final db = await database;
    await db.insert(tableMetadata, {
      'key': _dataAssetVersionKey,
      'value': version.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Versions-Check (Task D1): vergleicht die zuletzt importierte
  /// Asset-Version mit [dataAssetVersion]. Bei Abweichung (App-Update mit
  /// geänderten Wort-/Satz-/Wurzel-Daten, oder Erststart) werden
  /// `words`/`sentences`/`roots` geleert, damit die nachfolgenden
  /// `importXIfNeeded()`-Aufrufe sie aus den aktuellen Assets neu befüllen.
  /// `progress`/`batch_progress`/`learn_progress`/`purchases` bleiben
  /// unangetastet — vorausgesetzt, Word-IDs bleiben stabil (siehe
  /// [dataAssetVersion]-Doku). Muss vor den drei `importXIfNeeded()`-Aufrufen
  /// laufen (siehe `main.dart`).
  Future<void> reimportAssetDataIfVersionChanged() async {
    final storedVersion = await getStoredDataAssetVersion();
    if (storedVersion == dataAssetVersion) {
      return;
    }
    final db = await database;
    await db.delete(tableWords);
    await db.delete(tableSentences);
    await db.delete(tableRoots);
    await _setStoredDataAssetVersion(dataAssetVersion);
  }

  /// Alle Kontext-Sätze für [wordIds], gruppiert nach `word_id` (Task D1 —
  /// ersetzt das frühere direkte Lesen von `sentences.json` aus den Assets).
  Future<Map<int, List<Sentence>>> getSentencesByWordIds(
    Set<int> wordIds,
  ) async {
    if (wordIds.isEmpty) {
      return const {};
    }
    final db = await database;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    final rows = await db.query(
      tableSentences,
      where: 'word_id IN ($placeholders)',
      whereArgs: wordIds.toList(),
      // Deterministische Reihenfolge = Einfügereihenfolge aus sentences.json:
      // Satz 0/1/2 je Wort muss exakt der lautscripts/test_first_10.py
      // vergebenen Audio-Dateinummer entsprechen (siehe AudioService).
      orderBy: 'id',
    );
    final byWordId = <int, List<Sentence>>{};
    for (final row in rows) {
      final sentence = Sentence.fromMap(row);
      byWordId.putIfAbsent(sentence.wordId, () => []).add(sentence);
    }
    return byWordId;
  }

  /// Wurzel-Definitionen für [roots], indiziert nach der Wurzel selbst
  /// (Task D1 — ersetzt das frühere direkte Lesen von `roots.json` aus den
  /// Assets).
  Future<Map<String, WordRoot>> getRootsByKeys(Set<String> roots) async {
    if (roots.isEmpty) {
      return const {};
    }
    final db = await database;
    final placeholders = List.filled(roots.length, '?').join(',');
    final rows = await db.query(
      tableRoots,
      where: 'root IN ($placeholders)',
      whereArgs: roots.toList(),
    );
    return {
      for (final row in rows) row['root'] as String: WordRoot.fromMap(row),
    };
  }

  Future<List<Word>> getWordsByGroup(String group) async {
    final db = await database;
    final rows = await db.query(
      tableWords,
      where: '"group" = ?',
      whereArgs: [group],
      orderBy: 'frequency_rank ASC',
    );
    return rows.map(Word.fromMap).toList();
  }

  /// Alle Wörter einer Gruppe bis einschließlich [maxRank] (frequency_rank),
  /// nach Rang aufsteigend sortiert — die „bisher gelernten“ Wörter dieser
  /// Gruppe. Grundlage für den kumulativen Wortschatz der Geschichten-Stufe:
  /// die Geschichte der Lektion N soll Wörter aus den Lektionen 1..N
  /// verwenden, nicht nur die des aktuellen Batches. Wird beim Quiz-Start
  /// (getrackter Lauf) geladen; fehlt die Zeile, bleibt die Story auf den
  /// aktuellen Batch beschränkt (Fallback).
  Future<List<Word>> getWordsByGroupUpToRank(String group, int maxRank) async {
    final db = await database;
    final rows = await db.query(
      tableWords,
      where: '"group" = ? AND frequency_rank <= ?',
      whereArgs: [group, maxRank],
      orderBy: 'frequency_rank ASC',
    );
    return rows.map(Word.fromMap).toList();
  }

  /// Volltext-ähnliche Suche über `arabic`/`german`/`transliteration`
  /// (Task H2, Offline-Wörterbuch), sortiert nach `frequency_rank`. Leerer/
  /// whitespace-Query liefert eine leere Liste. Die Freischalt-Filterung
  /// geschieht im Aufrufer (über `word_groups.dart` `levelForRank` +
  /// freigeschaltete Sprachniveaus) — hier wird bewusst *alle* Treffer
  /// geliefert, damit kein PHP-/DB-Kontext an die Kauf-Logik koppelt.
  ///
  /// Arabisch wird **harakat-insensitiv** verglichen: Die Wörter sind mit
  /// Harakat/Tashkil gespeichert (z.B. `كَتَبَ`), typische Nutzer tippen aber
  /// ohne („كتب"). Daher werden Query *und* Wörter über [stripHarakat]
  /// normalisiert — sowohl Suche mit als auch ohne Harakat funktioniert.
  /// Die Transliteration wird über [normalizeTransliterationForSearch]
  /// normalisiert (DIN-Sonderzeichen → gängige ASCII-Form, z.B. „kataba"
  /// bzw. „qaraa"), Deutsch case-insensitiv.
  Future<List<Word>> searchWords(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final db = await database;
    final rows = await db.query(
      tableWords,
      orderBy: 'frequency_rank ASC',
    );
    final all = rows.map(Word.fromMap).toList();

    final arabicQuery = stripHarakat(trimmed);
    final translitQuery = normalizeTransliterationForSearch(trimmed);
    final lowerQuery = trimmed.toLowerCase();

    return [
      for (final w in all)
        if (stripHarakat(w.arabic).contains(arabicQuery) ||
            w.german.toLowerCase().contains(lowerQuery) ||
            normalizeTransliterationForSearch(w.transliteration)
                .contains(translitQuery))
          w,
    ];
  }

  /// Erhöht correct_count bzw. wrong_count für [wordId] und aktualisiert
  /// last_seen. Legt bei erstem Aufruf einen neuen Progress-Eintrag an.
  Future<void> updateProgress(int wordId, bool correct) async {
    final db = await database;
    final existing = await getProgress(wordId);
    final next = (existing ?? Progress(wordId: wordId)).copyWith(
      correctCount: (existing?.correctCount ?? 0) + (correct ? 1 : 0),
      wrongCount: (existing?.wrongCount ?? 0) + (correct ? 0 : 1),
      lastSeen: DateTime.now(),
    );
    await db.insert(
      tableProgress,
      next.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Progress?> getProgress(int wordId) async {
    final db = await database;
    final rows = await db.query(
      tableProgress,
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Progress.fromMap(rows.first);
  }

  Future<void> resetProgress() async {
    final db = await database;
    await db.delete(tableProgress);
  }

  /// Anteil (0.0–1.0) der Wörter in [group], die mindestens einmal richtig
  /// beantwortet wurden. Für die Fortschrittsanzeige im Home Screen (Task C4).
  Future<double> getGroupProgress(String group) async {
    final words = await getWordsByGroup(group);
    if (words.isEmpty) {
      return 0;
    }
    var masteredCount = 0;
    for (final word in words) {
      final progress = await getProgress(word.id);
      if (progress != null && progress.correctCount > 0) {
        masteredCount++;
      }
    }
    return masteredCount / words.length;
  }

  /// Anteil (0.0–1.0) der Wörter eines 100er-Blocks (Rangbereich
  /// [minRank]–[maxRank]) mit mindestens einer richtigen Antwort — für die
  /// Fortschrittsanzeige der Kauf-Blöcke im Home Screen (100er-Block-Umbau).
  Future<double> getRankRangeProgress(
    String group,
    int minRank,
    int maxRank,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableWords,
      where: '"group" = ? AND frequency_rank BETWEEN ? AND ?',
      whereArgs: [group, minRank, maxRank],
    );
    if (rows.isEmpty) {
      return 0;
    }
    var masteredCount = 0;
    for (final row in rows) {
      final wordId = row['id'] as int;
      final progress = await getProgress(wordId);
      if (progress != null && progress.correctCount > 0) {
        masteredCount++;
      }
    }
    return masteredCount / rows.length;
  }

  /// Markiert Batch [batchIndex] von [group] als fehlerfrei bestanden —
  /// schaltet damit den nächsten Batch frei. Mehrfacher Aufruf ist unschädlich.
  Future<void> markBatchPassed(String group, int batchIndex) async {
    final db = await database;
    await db.insert(tableBatchProgress, {
      'group_name': group,
      'batch_index': batchIndex,
      'passed_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<int>> getPassedBatchIndexes(String group) async {
    final db = await database;
    final rows = await db.query(
      tableBatchProgress,
      where: 'group_name = ?',
      whereArgs: [group],
    );
    return rows.map((row) => row['batch_index'] as int).toSet();
  }

  /// Anzahl konsekutiv bestandener Batches ab Index 0 (Batch 0 ist immer
  /// offen). Batch N ist spielbar, wenn `N <= highestUnlockedBatchIndex`.
  Future<int> highestUnlockedBatchIndex(String group) async {
    final passed = await getPassedBatchIndexes(group);
    var index = 0;
    while (passed.contains(index)) {
      index++;
    }
    return index;
  }

  /// Markiert Batch [batchIndex] von [group] als gelernt (Lernpfad einmal
  /// vollständig durchlaufen) — Sicherheits-Voraussetzung, bevor das Quiz
  /// dieses Batches spielbar ist. Mehrfacher Aufruf ist unschädlich.
  Future<void> markBatchLearned(String group, int batchIndex) async {
    final db = await database;
    await db.insert(tableLearnProgress, {
      'group_name': group,
      'batch_index': batchIndex,
      'completed_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<int>> getLearnedBatchIndexes(String group) async {
    final db = await database;
    final rows = await db.query(
      tableLearnProgress,
      where: 'group_name = ?',
      whereArgs: [group],
    );
    return rows.map((row) => row['batch_index'] as int).toSet();
  }

  /// Speichert/überschreibt den zuletzt angesehenen Wort-Index innerhalb
  /// eines Lern-Batches — damit ein Wiedereinstieg (Task: Lern-Zwischenstand)
  /// nach App-Neustart oder Verlassen des Screens genau dort fortsetzt statt
  /// wieder bei Wort 1 zu beginnen.
  Future<void> saveLearnPosition(
    String group,
    int batchIndex,
    int currentIndex,
  ) async {
    final db = await database;
    await db.insert(tableLearnPosition, {
      'group_name': group,
      'batch_index': batchIndex,
      'current_index': currentIndex,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// `null`, wenn für diesen Batch noch kein Zwischenstand gespeichert wurde
  /// (z.B. erster Aufruf oder nach [clearLearnPosition]).
  Future<int?> getLearnPosition(String group, int batchIndex) async {
    final db = await database;
    final rows = await db.query(
      tableLearnPosition,
      where: 'group_name = ? AND batch_index = ?',
      whereArgs: [group, batchIndex],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['current_index'] as int;
  }

  /// Löscht den Lern-Zwischenstand — aufgerufen, wenn der Nutzer den Batch
  /// bewusst von vorne beginnen möchte.
  Future<void> clearLearnPosition(String group, int batchIndex) async {
    final db = await database;
    await db.delete(
      tableLearnPosition,
      where: 'group_name = ? AND batch_index = ?',
      whereArgs: [group, batchIndex],
    );
  }

  /// Die zuletzt gespeicherte Lernposition über alle Gruppen hinweg (für die
  /// „Weiter lernen“-Karte auf der Startseite). Sortiert nach der impliziten
  /// SQLite-`rowid` absteigend: [saveLearnPosition] schreibt mit
  /// `ConflictAlgorithm.replace` (löscht die alte Zeile und fügt eine neue
  /// ein), wodurch die zuletzt geschriebene Zeile stets die höchste rowid
  /// erhält — „neueste zuerst“ ist damit deterministisch. `null`, wenn noch
  /// keine Lernposition gespeichert wurde.
  Future<({String group, int batchIndex, int currentIndex})?>
      getLatestLearnPosition() async {
    final db = await database;
    final rows = await db.query(
      tableLearnPosition,
      orderBy: 'rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return (
      group: row['group_name'] as String,
      batchIndex: row['batch_index'] as int,
      currentIndex: row['current_index'] as int,
    );
  }

  /// Ob alle Batches einer Gruppe (Batch-Anzahl aus [totalWords]/[batchSize])
  /// bestanden sind — Voraussetzung für die Gesamtprüfung.
  Future<bool> isGroupFullyPassed(
    String group,
    int totalWords,
    int batchSize,
  ) async {
    if (totalWords == 0) {
      return false;
    }
    final batchCount = (totalWords / batchSize).ceil();
    final passed = await getPassedBatchIndexes(group);
    return passed.length >= batchCount;
  }

  /// Schaltet das Sprachniveau [group] dauerhaft frei (z.B. nach erfolgreichem
  /// Kauf oder Restore). Mehrfacher Aufruf für dasselbe Niveau ist unschädlich.
  Future<void> unlockLevel(String group) async {
    final db = await database;
    await db.insert(tablePurchases, {
      'group_name': group,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Ob das Sprachniveau [group] freigeschaltet ist. Seit der App kostenlos
  /// ist (10. September 2026) gibt es keine Käufe mehr: Die **Einstiegs-Stufe**
  /// (erstes Level in `allLevels`, aktuell A1) ist immer frei; weitere Stufen
  /// werden beim Abschluss der vorherigen automatisch freigeschaltet (siehe
  /// `quiz_provider.dart`, `nextLevelAfter`). Die `purchases`-Tabelle bleibt
  /// als Persistenz für bereits freigeschaltete Stufen erhalten.
  Future<bool> isLevelUnlocked(String group) async {
    if (allLevels.isNotEmpty && allLevels.first.group == group) {
      return true;
    }
    final db = await database;
    final rows = await db.query(
      tablePurchases,
      where: 'group_name = ?',
      whereArgs: [group],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Alle freigeschalteten Sprachniveaus: immer die Einstiegs-Stufe
  /// (`allLevels.first`, aktuell A1) plus alle per Stufen-Abschluss
  /// freigeschalteten (persistiert in der `purchases`-Tabelle).
  Future<Set<String>> getUnlockedLevels() async {
    final unlocked = <String>{
      if (allLevels.isNotEmpty) allLevels.first.group,
    };
    final db = await database;
    final rows = await db.query(tablePurchases);
    for (final row in rows) {
      unlocked.add(row['group_name'] as String);
    }
    return unlocked;
  }

  /// Liefert eine persistente, einmalig erzeugte Geräte-ID (sie wird in der
  /// `metadata`-Tabelle gespeichert). Wird von der Freischalt-Code-Einlösung
  /// (Variante B) genutzt, um die server-signierte Freischalt-Antwort an genau
  /// dieses Gerät zu binden. Bewusst schlicht (Zeitstempel + Zufall) — kein
  /// Tracking, keine personenbezogenen Daten; nur eine Sitzungs-/Geräte-Markierung
  /// für die Signaturkette.
  Future<String> getOrCreateDeviceId() async {
    final db = await database;
    final rows = await db.query(
      tableMetadata,
      where: 'key = ?',
      whereArgs: [_deviceIdKey],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first['value'] as String;
    }
    final random = Random();
    final id =
        'd${DateTime.now().microsecondsSinceEpoch}${random.nextInt(0x7FFFFFFF)}';
    await db.insert(tableMetadata, {
      'key': _deviceIdKey,
      'value': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  /// Ob das First-Run-Onboarding bereits einmal abgeschlossen wurde
  /// (`onboarding_seen`-Flag in der `metadata`-Tabelle). `false` beim
  /// allerersten Start — dann zeigt die App vor der Startseite den
  /// Erklär-Screen (siehe `lib/screens/onboarding/onboarding_screen.dart`).
  Future<bool> isOnboardingSeen() async {
    final db = await database;
    final rows = await db.query(
      tableMetadata,
      where: 'key = ?',
      whereArgs: [_onboardingSeenKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    return rows.first['value'] == 'true';
  }

  /// Markiert das First-Run-Onboarding als abgeschlossen — aufgerufen beim
  /// Abschluss des Onboarding-Screens („Los geht’s“), damit es nur beim
  /// allerersten Start erscheint.
  Future<void> markOnboardingSeen() async {
    final db = await database;
    await db.insert(tableMetadata, {
      'key': _onboardingSeenKey,
      'value': 'true',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Speichert/überschreibt den Zwischenstand eines laufenden, getrackten
  /// Batch-Quiz (Task G3, Anti-Cheat) — siehe [QuizSession].
  Future<void> saveQuizSession(QuizSession session) async {
    final db = await database;
    await db.insert(
      tableQuizSession,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<QuizSession?> getQuizSession(String group, int batchIndex) async {
    final db = await database;
    final rows = await db.query(
      tableQuizSession,
      where: 'group_name = ? AND batch_index = ?',
      whereArgs: [group, batchIndex],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return QuizSession.fromMap(rows.first);
  }

  /// Löscht den Zwischenstand — aufgerufen, sobald ein Quiz-Lauf regulär zu
  /// Ende gespielt wurde (bestanden oder nicht). Nur ein vor Abschluss
  /// unterbrochener Lauf soll beim nächsten Öffnen fortgesetzt werden.
  Future<void> clearQuizSession(String group, int batchIndex) async {
    final db = await database;
    await db.delete(
      tableQuizSession,
      where: 'group_name = ? AND batch_index = ?',
      whereArgs: [group, batchIndex],
    );
  }

  /// Lokales Datum als sortierbarer Schlüssel `'YYYY-MM-DD'` — verwendet für
  /// die `study_activity`-Tabelle (Task: Heatmap/Streak). Ist die Datums-
  /// "Währung" der Statistik: Vergleiche (`>=`/`<=`/PK) funktionieren
  /// lexikographisch, weil das Format linksbündig mit großen Einheiten beginnt.
  static String studyDateKey(DateTime date) {
    return '${date.year.toString()}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseStudyDate(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static bool _isNextStudyDay(String earlierKey, String laterKey) {
    final earlier = _parseStudyDate(earlierKey);
    final later = _parseStudyDate(laterKey);
    return later.difference(earlier).inDays == 1;
  }

  static String _previousStudyDayKey(String dateKey) {
    return studyDateKey(
      _parseStudyDate(dateKey).subtract(const Duration(days: 1)),
    );
  }

  /// Zählt Lernaktivität für den heutigen lokalen Tag (Task: Lernstatistiken).
  /// Mehrere Aufrufe am selben Tag erhöhen die Zähler der vorhandenen Zeile
  /// (UPSERT statt Duplikat). Aufruf ist bewusst fire-and-forget aus den
  /// Lern-/Quiz-Providern — analog zu `saveLearnPosition`/`saveQuizSession`.
  Future<void> trackStudyActivity({
    int wordsViewed = 0,
    int quizAnswers = 0,
    int lessonsCompleted = 0,
  }) async {
    final increments = wordsViewed + quizAnswers + lessonsCompleted;
    if (increments <= 0) {
      return;
    }
    final db = await database;
    final today = studyDateKey(DateTime.now());
    // Atomares UPSERT: fire-and-forget-Aufrufe (Lern-/Quiz-Provider) können
    // parallel laufen — ein read-modify-write würde bei zwei gleichzeitigen
    // Erstaufrufen desselben Tages auf einen UNIQUE-Constraint-Fehler laufen.
    // `ON CONFLICT(date) DO UPDATE` inkrementiert die vorhandene Zeile
    // atomar, bzw. legt sie beim ersten Aufruf an.
    await db.rawInsert(
      'INSERT INTO $tableStudyActivity '
      '(date, activity_count, words_viewed, quiz_answers, lessons_completed) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(date) DO UPDATE SET '
      'activity_count = activity_count + ?, '
      'words_viewed = words_viewed + ?, '
      'quiz_answers = quiz_answers + ?, '
      'lessons_completed = lessons_completed + ?',
      [
        today,
        increments,
        wordsViewed,
        quizAnswers,
        lessonsCompleted,
        increments,
        wordsViewed,
        quizAnswers,
        lessonsCompleted,
      ],
    );
  }

  /// Aktivität (Interaktionen je lokalam Tag) im Datumsfenster [start]–[end]
  /// als `Map<'YYYY-MM-DD', activity_count>` — Grundlage für Streak- und
  /// Heatmap-Berechnung. Tage ohne Aktivität tauchen nicht in der Map auf.
  Future<Map<String, int>> getStudyActivityForRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableStudyActivity,
      where: 'date >= ? AND date <= ?',
      whereArgs: [studyDateKey(start), studyDateKey(end)],
      orderBy: 'date',
    );
    return <String, int>{
      for (final row in rows) row['date'] as String: row['activity_count'] as int,
    };
  }

  /// Kennzahlen (aktuelle/beste Serie, aktive Tage, Heute-Zähler) aus einer
  /// Datums->Aktivitäts-Map (Schlüssel `'YYYY-MM-DD'`). Pure Dart-Logik ohne
  /// DB-Zugriff — für Unit-Tests direkt aufrufbar. Die aktuelle Serie zählt
  /// bis einschließlich [today]; war heute noch keine Aktivität, wird ein
  /// gestern verankerter Streak bis Mitternacht als "verlängerbar" weiterge-
  /// zählt (motivierender für den Tagesübergang).
  static StudyStats computeStudyStats(
    Map<String, int> activityByDate,
    DateTime today,
  ) {
    final todayKey = studyDateKey(today);
    final activeKeys = <String>{
      for (final entry in activityByDate.entries)
        if (entry.value > 0) entry.key,
    };
    if (activeKeys.isEmpty) {
      return StudyStats(
        currentStreak: 0,
        bestStreak: 0,
        activeDays: 0,
        todayCount: activityByDate[todayKey] ?? 0,
      );
    }

    final sorted = activeKeys.toList()..sort();
    var bestStreak = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (_isNextStudyDay(sorted[i - 1], sorted[i])) {
        run++;
      } else {
        run = 1;
      }
      if (run > bestStreak) {
        bestStreak = run;
      }
    }

    var currentStreak = 0;
    var day =
        activeKeys.contains(todayKey) ? todayKey : _previousStudyDayKey(todayKey);
    while (activeKeys.contains(day)) {
      currentStreak++;
      day = _previousStudyDayKey(day);
    }

    return StudyStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      activeDays: activeKeys.length,
      todayCount: activityByDate[todayKey] ?? 0,
    );
  }

  /// Detaillierte Aktivität eines einzelnen Tages (`words_viewed`/
  /// `quiz_answers`/`lessons_completed`) — für die "Heute"-Karte im
  /// Statistik-Tab. Zeilen ohne Eintrag liefern Null-Zähler.
  Future<StudyDayActivity> getStudyDayActivity(DateTime day) async {
    final db = await database;
    final rows = await db.query(
      tableStudyActivity,
      where: 'date = ?',
      whereArgs: [studyDateKey(day)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return StudyDayActivity(
        activityCount: 0,
        wordsViewed: 0,
        quizAnswers: 0,
        lessonsCompleted: 0,
      );
    }
    final row = rows.first;
    return StudyDayActivity(
      activityCount: row['activity_count'] as int,
      wordsViewed: row['words_viewed'] as int,
      quizAnswers: row['quiz_answers'] as int,
      lessonsCompleted: row['lessons_completed'] as int,
    );
  }

  /// Kompletter Überblick für den Statistik-Tab: Kennzahlen, Aktivität je Tag
  /// der letzten [heatmapDays] Tage (einschließlich heute) und die heutige
  /// Detailaktivität — ein einzelner Abruf für den Tab.
  Future<StudyOverview> getStudyOverview(DateTime today, int heatmapDays) async {
    final start = today.subtract(Duration(days: heatmapDays - 1));
    final activity = await getStudyActivityForRange(start, today);
    return StudyOverview(
      stats: computeStudyStats(activity, today),
      activityByDate: activity,
      today: await getStudyDayActivity(today),
    );
  }

  /// Fügt alle Wörter einer bestandenen Lektion [batchIndex] von [group] in
  /// den SM-2-Wiederholungs-Pool ein (Task: Spaced Repetition). Die Wörter
  /// sind ab sofort fällig (`due_date` = heute, Intervall 0), damit der
  /// Nutzer direkt nach dem Bestehen mit der Wiederholung beginnen kann.
  /// Bereits im Pool stehende Wörter (z.B. bei wiederholtem Bestehen oder
  /// Lektion erreicht mit bereits gepoolten Wörtern) bleiben unangetastet
  /// (`ConflictAlgorithm.ignore` — ein Re-Passen verlängert keine Intervalle).
  Future<void> seedSm2ForBatch(String group, int batchIndex) async {
    final db = await database;
    final startRank = batchIndex * learnBatchSize + 1;
    final rows = await db.query(
      tableWords,
      where: '"group" = ? AND frequency_rank BETWEEN ? AND ?',
      whereArgs: [group, startRank, startRank + learnBatchSize - 1],
      orderBy: 'frequency_rank ASC',
    );
    if (rows.isEmpty) {
      return;
    }
    final todayKey = studyDateKey(DateTime.now());
    final batch = db.batch();
    for (final row in rows) {
      final wordId = row['id'] as int;
      batch.insert(
        tableSm2State,
        Sm2State(dueDate: todayKey).toMap(wordId),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Wertet eine Selbstbewertung [quality] (SM-2-Qualität 0–5) für [wordId]
  /// aus: liest den aktuellen Pool-Zustand (bzw. den Startzustand eines noch
  /// nicht gepoolten Worts), berechnet über [Sm2.review] den nächsten
  /// Zustand und speichert ihn (`due_date` = [today] + Intervall). Mehrfache
  /// Aufrufe sind unschädlich (`ConflictAlgorithm.replace`).
  Future<void> recordSm2Review(
    int wordId,
    int quality,
    DateTime today,
  ) async {
    final db = await database;
    final current = await getSm2State(wordId);
    final next = Sm2.review(
      repetitions: current?.repetitions ?? 0,
      easeFactor: current?.easeFactor ?? Sm2.initialEaseFactor,
      intervalDays: current?.intervalDays ?? 0,
      quality: quality,
    );
    final nextState = Sm2State(
      repetitions: next.repetitions,
      easeFactor: next.easeFactor,
      intervalDays: next.intervalDays,
      dueDate: studyDateKey(today.add(Duration(days: next.intervalDays))),
      lastQuality: quality < 0 ? 0 : (quality > 5 ? 5 : quality),
    );
    await db.insert(
      tableSm2State,
      nextState.toMap(wordId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Aktueller SM-2-Zustand für [wordId]; `null`, wenn das Wort noch nicht
  /// im Wiederholungs-Pool liegt (noch keine Lektion damit bestanden).
  Future<Sm2State?> getSm2State(int wordId) async {
    final db = await database;
    final rows = await db.query(
      tableSm2State,
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Sm2State.fromMap(rows.first);
  }

  /// Anzahl fälliger Wörter im SM-2-Pool (`due_date <= [today]`) — für die
  /// „Wiederholen“-Karte der Startseite (Null-Niveau, falls noch nichts
  /// bestanden wurde).
  Future<int> getDueSm2Count(DateTime today) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableSm2State WHERE due_date <= ?',
      [studyDateKey(today)],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Alle fälligen Wörter inkl. aktuellem SM-2-Zustand, sortiert nach
  /// Fälligkeit und Wort-ID — die Session-Queue des Wiederholungs-Screens.
  /// Wörter, deren Zeile nicht mehr auf `words` zeigt (z.B. nach einem
  /// Daten-Reimport), werden übersprungen.
  Future<List<Sm2ReviewItem>> getDueSm2Words(DateTime today) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM $tableSm2State WHERE due_date <= ? '
      'ORDER BY due_date ASC, word_id ASC',
      [studyDateKey(today)],
    );
    if (rows.isEmpty) {
      return const [];
    }
    final statesById = <int, Sm2State>{
      for (final row in rows) row['word_id'] as int: Sm2State.fromMap(row),
    };
    final ids = statesById.keys.toList();
    final placeholders = ids.map((_) => '?').join(', ');
    final wordRows = await db.query(
      tableWords,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    final wordsById = <int, Word>{
      for (final row in wordRows) row['id'] as int: Word.fromMap(row),
    };
    return [
      for (final id in ids)
        if (wordsById.containsKey(id))
          Sm2ReviewItem(word: wordsById[id]!, state: statesById[id]!),
    ];
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
