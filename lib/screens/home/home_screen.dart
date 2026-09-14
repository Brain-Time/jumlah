import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/animated_progress_bar.dart';
import '../../core/word_groups.dart';
import '../dictionary/dictionary_screen.dart';
import '../info/info_screen.dart';
import '../learn/learn_screen.dart';
import '../review/review_screen.dart';
import '../stats/stats_screen.dart';
import 'batch_list_screen.dart';

/// Hauptmenü mit Bottom Navigation (Task C4): Lernen · Quiz · Statistik · Info.
/// Erste Anlaufstelle der App, verbindet alle zuvor gebauten Screens.
/// Der Store-Bereich wurde entfernt (10. September 2026): Alle Sprachniveaus
/// erscheinen direkt hier auf der Startseite; die Freischaltung der Stufen
/// erfolgt durch Abschluss der vorherigen (keine Käufe mehr).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [_LearnTab(), _QuizTab(), StatsTab(), InfoScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Lernen'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Quiz'),
          // Statistik-Tab (Task: Lernstatistiken Heatmap/Streak): Serie,
          // aktive Tage und 16-Wochen-Heatmap — siehe stats_screen.dart.
          NavigationDestination(icon: Icon(Icons.insert_chart), label: 'Statistik'),
          // Task „Info“-Menü: Support- & Rechts-Einträge (siehe info_screen.dart).
          NavigationDestination(icon: Icon(Icons.info), label: 'Info'),
        ],
      ),
    );
  }
}

class _LearnTab extends ConsumerStatefulWidget {
  const _LearnTab();

  @override
  ConsumerState<_LearnTab> createState() => _LearnTabState();
}

class _QuizTab extends ConsumerStatefulWidget {
  const _QuizTab();

  @override
  ConsumerState<_QuizTab> createState() => _QuizTabState();
}

class _LearnTabState extends _LevelsTabState<_LearnTab> {
  _LearnTabState() : super(false);
}

class _QuizTabState extends _LevelsTabState<_QuizTab> {
  _QuizTabState() : super(true);
}

/// Gemeinsamer Zustand für Lernen- und Quiz-Tab: zeigt **alle**
/// Sprachniveaus (auch geplante A2–C1) direkt auf der Startseite — „alles
/// auf der Homepage“ statt separatem Store (seit 10. September 2026). Die
/// Einstiegs-Stufe (A1) ist immer freigeschaltet; jede weitere Stufe erst
/// nach Abschluss der vorherigen (`DatabaseHelper.getUnlockedLevels` —
/// Abschluss-Freischaltung statt Kauf). Nach der Rückkehr von einem
/// Navigations-Push wird der Freischalt-Status neu geladen (z.B. wenn ein
/// Quiz die letzte Lektion einer Stufe bestanden hat).
///
/// Der Lernen-Tab zeigt zusätzlich ein Hero-Banner mit Statistik-Zeile und
/// eine „Weiter lernen“-Resume-Karte (Task „Erste Seite professioneller“);
/// die dafür geladenen Felder (`_latestPosition`/`_homeStats`) bleiben im
/// Quiz-Tab ungenutzt (inert).
abstract class _LevelsTabState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  _LevelsTabState(this.isQuiz);

  final bool isQuiz;

  Set<String> _unlockedLevels = const {};

  /// Zuletzt gespeicherte Lernposition (für die „Weiter lernen“-Karte),
  /// `null` solange der Nutzer noch keine Lektion geöffnet hat.
  ({String group, int batchIndex, int currentIndex})? _latestPosition;

  /// Banner-Statistik (Wörter/Lektionen/Fortschritt über die aktiven
  /// Sprachniveaus — aktuell A1).
  _HomeStats _homeStats = const _HomeStats();

  /// Anzahl aktuell fälliger Wörter im SM-2-Wiederholungs-Pool (Task:
  /// Spaced Repetition) — für die „Wiederholen“-Karte.
  int _dueReviewWords = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLevels);
    if (!isQuiz) {
      Future.microtask(_loadHomeData);
    }
  }

  Future<void> _loadLevels() async {
    final unlocked = await DatabaseHelper.instance.getUnlockedLevels();
    if (!mounted) {
      return;
    }
    setState(() => _unlockedLevels = unlocked);
  }

  /// Lädt die Daten für Hero-Banner (Statistik) und „Weiter lernen“-Karte
  /// (zuletzt geöffnete Lektion). Wird auch nach der Rückkehr aus einer
  /// Lektion erneut aufgerufen, damit sich die Resume-Karte aktualisiert.
  Future<void> _loadHomeData() async {
    final latest = await DatabaseHelper.instance.getLatestLearnPosition();
    final stats = await _computeHomeStats();
    final dueReviewWords =
        await DatabaseHelper.instance.getDueSm2Count(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() {
      _latestPosition = latest;
      _homeStats = stats;
      _dueReviewWords = dueReviewWords;
    });
  }

  /// Summiert `wordCount`/`lessonsPerLevel` und den gewichteten Fortschritt
  /// über alle **aktiven** (nicht geplanten) Sprachniveaus — aktuell nur A1
  /// (500 Wörter / 50 Lektionen), zukunftsfähig auch für weitere Stufen.
  Future<_HomeStats> _computeHomeStats() async {
    var words = 0;
    var lessons = 0;
    var weightedProgress = 0.0;
    var progressDenominator = 0;
    for (final level in allLevels) {
      if (level.planned) {
        continue;
      }
      words += level.wordCount;
      lessons += level.lessonsPerLevel;
      final p = await DatabaseHelper.instance.getRankRangeProgress(
        level.group,
        level.startRank,
        level.endRank,
      );
      weightedProgress += p * level.wordCount;
      progressDenominator += level.wordCount;
    }
    final progress =
        progressDenominator == 0 ? 0.0 : weightedProgress / progressDenominator;
    return _HomeStats(words: words, lessons: lessons, progress: progress);
  }

  /// „Weiter lernen“: springt direkt in die zuletzt geöffnete Lektion
  /// (`LearnScreen` setzt beim gespeicherten Wort fort); ohne Lernposition
  /// in die erste Lektion des Einstiegs-Niveaus (A1, Batch 0).
  Future<void> _openContinue() async {
    final group =
        _latestPosition?.group ??
        (allLevels.isEmpty ? null : allLevels.first.group);
    if (group == null) {
      return;
    }
    final batchIndex = _latestPosition?.batchIndex ?? 0;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearnScreen(group: group, batchIndex: batchIndex),
      ),
    );
    if (mounted) {
      await _loadLevels();
      await _loadHomeData();
    }
  }

  Future<void> _openLevel(BuildContext context, WordLevelInfo info) async {
    if (info.planned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sprachniveau ${info.group} ist in Vorbereitung — kommt bald.',
          ),
        ),
      );
      return;
    }
    if (!_unlockedLevels.contains(info.group)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Schließe zuerst das vorherige Sprachniveau ab, um '
            '${info.group} freizuschalten.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchListScreen(
          group: info.group,
          mode: isQuiz ? BatchListMode.quiz : BatchListMode.learn,
        ),
      ),
    );
    if (mounted) {
      await _loadLevels();
      if (!isQuiz) {
        // Auch die Home-Daten („Weiter lernen“-Karte, Fälligkeits-Zähler der
        // Wiederholen-Karte) nach der Rückkehr aktualisieren.
        await _loadHomeData();
      }
    }
  }

  /// „Wiederholen“: öffnet die SM-2-Wiederholungs-Session (fällige Wörter);
  /// nach der Rückkehr wird der Fälligkeits-Zähler neu geladen.
  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
    if (mounted) {
      await _loadLevels();
      await _loadHomeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isQuiz ? 'Quiz' : 'Lernen'),
        actions: [
          if (!isQuiz)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Wörterbuch',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DictionaryScreen(),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isQuiz ? _buildQuizBody(context) : _buildLearnBody(context),
      ),
    );
  }

  /// Quiz-Tab: kompakter Kopf („Schulprüfung“) über der scrollenden
  /// Niveau-Liste (unverändert).
  Widget _buildQuizBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schulprüfung',
                style: AppTheme.headingStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                'Prüfe dein Wissen Stufe für Stufe.',
                style: AppTheme.secondaryStyle(),
              ),
            ],
          ),
        ),
        Expanded(child: _buildLevelList(context)),
      ],
    );
  }

  /// Lernen-Tab: eine scrollende Seite mit Hero-Banner (Begrüßung +
  /// Statistik), „Weiter lernen“-Resume-Karte und Sektions-Überschrift,
  /// gefolgt von den Sprachniveau-Kacheln.
  Widget _buildLearnBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _HeroBanner(stats: _homeStats),
        const SizedBox(height: 12),
        _ContinueCard(position: _latestPosition, onTap: _openContinue),
        const SizedBox(height: 12),
        _ReviewCard(dueCount: _dueReviewWords, onTap: _openReview),
        const SizedBox(height: 22),
        Text('Sprachniveaus', style: AppTheme.headingStyle(fontSize: 18)),
        const SizedBox(height: 12),
        for (final info in allLevels)
          GroupProgressTile(
            info: info,
            unlocked: _unlockedLevels.contains(info.group),
            planned: info.planned,
            heroTag: levelTitleHeroTag(info.group, isQuiz: isQuiz),
            onTap: () => _openLevel(context, info),
          ),
      ],
    );
  }

  Widget _buildLevelList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: allLevels.length,
      itemBuilder: (context, index) {
        final info = allLevels[index];
        return GroupProgressTile(
          info: info,
          unlocked: _unlockedLevels.contains(info.group),
          planned: info.planned,
          heroTag: levelTitleHeroTag(info.group, isQuiz: isQuiz),
          onTap: () => _openLevel(context, info),
        );
      },
    );
  }
}

/// Sprachniveau-Kachel mit Fortschrittsbalken und Status-Hinweis. Von Lernen-
/// und Quiz-Tab gemeinsam genutzt. Task UI-1: professionellere Ebenen
/// (surface + Border + Schatten), klarere Typografie, Status-Chip und
/// Prozent-/Milestone-Anzeige statt flacher Flächen.
class GroupProgressTile extends StatelessWidget {
  const GroupProgressTile({
    super.key,
    required this.info,
    required this.unlocked,
    required this.onTap,
    this.planned = false,
    this.heroTag,
  });

  final WordLevelInfo info;

  /// Ob das gesamte Sprachniveau freigeschaltet ist (Einstiegs-Stufe A1
  /// immer; weitere Stufen nach Abschluss der vorherigen).
  final bool unlocked;

  /// Ob die Stufe geplant, aber noch nicht als Inhalte hinterlegt ist
  /// (A2–C1) — zeigt „Bald verfügbar“ statt Navigation.
  final bool planned;

  final VoidCallback onTap;

  /// Task E1: Hero-Übergang des Titels in `BatchListScreen`s AppBar, wenn
  /// gesetzt (siehe `levelTitleHeroTag`).
  final Object? heroTag;

  /// „Sprachniveau A1 · Label“ — Text exakt so belassen (Hero-/Test-Kompatibilität).
  String get _title => 'Sprachniveau ${info.group} · ${info.label}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.cardPadding,
              vertical: 12,
            ),
            decoration: AppTheme.cardDecoration(
              color: unlocked ? AppColors.surfaceElevated : AppColors.surface,
              borderColor: unlocked ? AppColors.border : Colors.transparent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BlockIcon(unlocked: unlocked),
                const SizedBox(width: 14),
                Expanded(child: _buildContent(context)),
                const SizedBox(width: 8),
                Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: unlocked ? AppColors.primary : AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final title = Text(_title, style: AppTheme.titleStyle(fontSize: 15));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heroTag == null
            ? title
            : Hero(
                tag: heroTag!,
                child: Material(type: MaterialType.transparency, child: title),
              ),
        const SizedBox(height: 4),
        // Fortschritt immer anzeigen (Einstiegs-Lektionen sind frei spielbar);
        // bei ungekauftem Sprachniveau zusätzlich ein Kauf-Hinweis-Chip.
        FutureBuilder<double>(
          future: DatabaseHelper.instance.getRankRangeProgress(
            info.group,
            info.startRank,
            info.endRank,
          ),
          builder: (context, snapshot) {
            final value = snapshot.data ?? 0;
            final percent = (value * 100).round();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Wörter ${info.startRank}–${info.endRank}',
                      style: AppTheme.secondaryStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '$percent %',
                      style: AppTheme.secondaryStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedProgressBar(
                  value: value,
                  color: AppColors.success,
                  minHeight: 6,
                ),
                const SizedBox(height: 6),
                _Milestone(
                  value: value,
                  lessonsPerLevel: info.lessonsPerLevel,
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  _MiniChip(
                    label: 'Vorheriges Niveau abschließen',
                    icon: Icons.lock_clock,
                  ),
                ] else if (planned) ...[
                  const SizedBox(height: 8),
                  _MiniChip(
                    label: 'Bald verfügbar',
                    icon: Icons.schedule,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Marken-Badge (Sprachniveau-Kürzel) je Kachel — deutlicher Akzent statt
/// leerer Fläche.
class _BlockIcon extends StatelessWidget {
  const _BlockIcon({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final accent = unlocked ? AppColors.success : AppColors.primary;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Icon(
        unlocked ? Icons.school : Icons.lock_clock,
        color: accent,
        size: 22,
      ),
    );
  }
}

/// Mini-Badge, z. B. „Im Store freischalten“ auf gesperrten Kacheln.
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.secondaryStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Kleine Milestone-Zeile: wie viele von [lessonsPerLevel] Lektionen im
/// Sprachniveau fortgeschritten sind — motivierender als ein nackter Balken.
class _Milestone extends StatelessWidget {
  const _Milestone({required this.value, required this.lessonsPerLevel});

  final double value; // 0.0–1.0
  final int lessonsPerLevel;

  @override
  Widget build(BuildContext context) {
    final lessonsDone = (value * lessonsPerLevel)
        .clamp(0, lessonsPerLevel)
        .round();
    final label =
        lessonsDone >= lessonsPerLevel
            ? 'Sprachniveau abgeschlossen ✅'
            : lessonsDone == 0
            ? 'Beginne die erste Lektion'
            : 'Lektion $lessonsDone von $lessonsPerLevel im Sprachniveau';
    return Row(
      children: [
        Icon(
          lessonsDone >= lessonsPerLevel ? Icons.emoji_events : Icons.menu_book,
          size: 14,
          color: lessonsDone >= lessonsPerLevel
              ? AppColors.gold
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.secondaryStyle()),
      ],
    );
  }
}

/// Statistik-Werte des Hero-Banners (Task „Erste Seite professioneller“):
/// Summe der aktiven Sprachniveaus (aktuell nur A1) plus gewichteter
/// Fortschritt — „500 Wörter · 50 Lektionen · X %“.
class _HomeStats {
  const _HomeStats({this.words = 0, this.lessons = 0, this.progress = 0.0});

  final int words;
  final int lessons;

  /// Gewichteter Fortschritt über die aktiven Sprachniveaus, 0.0–1.0.
  final double progress;
}

/// Hero-Banner des Lernen-Tabs: Logo, Begrüßung (أَهْلًا وَسَهْلًا), Tagline
/// und die Statistik-Zeile (Wörter · Lektionen · Fortschritt).
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.stats});

  final _HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final percent = (stats.progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceElevated,
        borderColor: AppColors.primary.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/branding/jumla_logo.png', width: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'أَهْلًا وَسَهْلًا',
                        style: AppTheme.arabicTextStyle(
                          fontSize: 22,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Willkommen bei Jumlah',
                      style: AppTheme.titleStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lerne klassisches Arabisch — offline & kostenlos.',
                      style: AppTheme.secondaryStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatItem(
                icon: Icons.menu_book,
                label: 'Wörter',
                value: '${stats.words}',
              ),
              const SizedBox(width: 8),
              _StatItem(
                icon: Icons.list_alt,
                label: 'Lektionen',
                value: '${stats.lessons}',
              ),
              const SizedBox(width: 8),
              _StatItem(
                icon: Icons.trending_up,
                label: 'Fortschritt',
                value: '$percent %',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ein Statistik-Kästchen im Hero-Banner (Icon, Wert, Label).
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.dark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.titleStyle(fontSize: 16)),
            Text(label, style: AppTheme.secondaryStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}


/// „Weiter lernen“-Resume-Karte: springt direkt in die zuletzt geöffnete
/// Lektion (mit Wort-Position); ohne gespeicherte Lernposition als
/// „Beginne zu lernen“ (erste Lektion des Einstiegs-Niveaus).
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.position, required this.onTap});

  final ({String group, int batchIndex, int currentIndex})? position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pos = position;
    final hasPosition = pos != null;
    final group =
        pos?.group ?? (allLevels.isEmpty ? 'A1' : allLevels.first.group);
    final lesson = (pos?.batchIndex ?? 0) + 1;
    final word = pos == null ? 1 : pos.currentIndex + 1;
    final subtitle = hasPosition
        ? 'Lektion $lesson · Wort $word von 10 · $group'
        : 'Lektion 1 · Wörter 1–10 · $group';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.cardDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderColor: AppColors.primary.withValues(alpha: 0.45),
          ),
          child: Row(
            children: [
              Icon(
                hasPosition ? Icons.play_circle_fill : Icons.flag,
                color: AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPosition ? 'Weiter lernen' : 'Beginne zu lernen',
                      style: AppTheme.titleStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.secondaryStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// „Wiederholen“-Karte (Task: Spaced Repetition/SM-2): zeigt die Anzahl
/// aktuell fälliger Wörter und öffnet die Wiederholungs-Session. Im Leer-
/// Zustand (noch nichts bestanden oder nichts fällig) ein motivierender
/// Hinweis.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.dueCount, required this.onTap});

  final int dueCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDue = dueCount > 0;
    final subtitle = hasDue
        ? '$dueCount ${dueCount == 1 ? 'Wort' : 'Wörter'} fällig — Zeit für '
            'eine Wiederholung.'
        : 'Bestehe Lektionen, um Wörter hier zu wiederholen.';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.cardDecoration(
            color: hasDue
                ? AppColors.gold.withValues(alpha: 0.10)
                : AppColors.surface,
            borderColor: hasDue
                ? AppColors.gold.withValues(alpha: 0.45)
                : AppColors.border,
          ),
          child: Row(
            children: [
              Icon(
                Icons.autorenew,
                color: hasDue ? AppColors.gold : AppColors.textSecondary,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wiederholen',
                      style: AppTheme.titleStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.secondaryStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: hasDue ? AppColors.gold : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}