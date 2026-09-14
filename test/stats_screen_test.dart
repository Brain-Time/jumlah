import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/core/database/database_helper.dart';
import 'package:jumlah/screens/stats/stats_screen.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sqlite_ffi_test_setup.dart';

/// Widget-Tests für den Statistik-Tab (Task: Lernstatistiken Heatmap/Streak).
/// Der Tab lädt seine Daten über `FutureBuilder` aus einer echten SQLite-DB —
/// deshalb laufen pump/lade-Vorgänge wie in den anderen Screen-Tests innerhalb
/// von `tester.runAsync(...)` (Bekannte FFI-FakeAsync-Erkenntnis, siehe C1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    setUpLinuxSqlite3Fallback();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    tempDir = Directory.systemTemp.createTempSync('jumlah_stats_screen_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dbFile = File(p.join(tempDir.path, DatabaseHelper.databaseName));
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  Future<void> pumpStatsTab(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StatsTab())),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
    });
  }

  testWidgets('StatsTab zeigt den Leer-Zustand ohne jede Lernaktivität', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await pumpStatsTab(tester);

    expect(find.text('Statistik'), findsOneWidget);
    expect(find.textContaining('Noch keine Lernaktivität'), findsOneWidget);
    expect(find.text('Tage Serie'), findsOneWidget);
    expect(find.text('Deine Lernaktivität'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('StatsTab zeigt Serie, Heute-Karte und Heatmap nach Aktivität', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.runAsync(() async {
      await DatabaseHelper.instance.trackStudyActivity(
        wordsViewed: 3,
        quizAnswers: 5,
      );
      await DatabaseHelper.instance.trackStudyActivity(quizAnswers: 1);
    });

    await pumpStatsTab(tester);

    // Leer-Zustand ist verschwunden, Kennzahlen und Heute-Karte sind da.
    expect(find.textContaining('Noch keine Lernaktivität'), findsNothing);
    expect(find.text('Aktive Tage'), findsOneWidget);
    expect(find.text('Wörter angesehen'), findsOneWidget);
    expect(find.text('Quiz-Antworten'), findsOneWidget);

    // Heute-Zähler: 3 Wörter, 6 Quiz-Antworten, 9 Interaktionen gesamt.
    expect(find.text('3'), findsWidgets);
    expect(find.text('6'), findsWidgets);
    expect(find.text('9'), findsWidgets);

    // Heatmap: genau der heutige Tag ist aktiv. Der Tooltip der heutigen
    // Zelle leitet sich direkt aus `activityByDate` ab (Format
    // `'$dateKey · $count Aktivitäten'`) — da Tooltip-Widgets in diesem
    // Test-Binding nicht als Elemente einsehbar sind, wird hier dieselbe
    // Datenbasis abgesichert, die den Tooltip speist (9 Aktivitäten heute,
    // ein aktiver Tag in der 16-Wochen-Heatmap).
    final todayKey = DatabaseHelper.studyDateKey(DateTime.now());
    final overview = await DatabaseHelper.instance.getStudyOverview(
      DateTime.now(),
      StatsTab.heatmapDays,
    );
    expect(overview.activityByDate[todayKey], 9);
    expect(overview.stats.activeDays, 1);

    debugDefaultTargetPlatformOverride = null;
  });
}