import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';

/// Statistik-Tab der Startseite (Task: Lernstatistiken Heatmap/Streak).
/// Zeigt aktuelle Serie, beste Serie, aktive Tage, die heutige Aktivität und
/// eine GitHub-Style-Heatmap der letzten [StatsTab.heatmapWeeks] Wochen.
///
/// Der Tab ist bewusst stateless: Ein [FutureBuilder] lädt die Daten bei jedem
/// Aufbau frisch aus SQLite — so bleibt die Statistik nach einer Lern-/
/// Quiz-Session automatisch aktuell, sobald der Tab neu gerendert wird, ohne
/// dass hier eigene State-Verwaltung nötig wäre.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  /// Wie viele Wochen die Heatmap rückwärts abdeckt (16 Wochen = 112 Tage).
  static final int heatmapWeeks = 16;
  static final int heatmapDays = heatmapWeeks * 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: SafeArea(
        child: FutureBuilder<StudyOverview>(
          future: DatabaseHelper.instance.getStudyOverview(
            DateTime.now(),
            heatmapDays,
          ),
          builder: (context, snapshot) => _buildBody(snapshot.data),
        ),
      ),
    );
  }

  Widget _buildBody(StudyOverview? overview) {
    if (overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = overview.stats;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats.activeDays == 0 && overview.today.activityCount == 0)
            const _EmptyHint(),
          _StatRow(stats: stats, todayCount: overview.today.activityCount),
          const SizedBox(height: 14),
          _TodayCard(today: overview.today),
          const SizedBox(height: 14),
          _HeatmapCard(activityByDate: overview.activityByDate),
        ],
      ),
    );
  }
}

/// Hinweis-Karte im Leer-Zustand (noch keine einzige Lernaktivität).
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceElevated,
        borderColor: AppColors.gold.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 26, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Noch keine Lernaktivität',
                  style: AppTheme.titleStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sobald du eine Lektion durchblätterst oder eine Quiz-Frage '
            'beantwortest, wertet Jumlah deine Serie und diese Heatmap aus — '
            'automatisch und komplett offline.',
            style: AppTheme.secondaryStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Die vier Kopf-Kacheln: Aktuelle Serie · Beste Serie · Aktive Tage · Heute.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats, required this.todayCount});

  final StudyStats stats;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.local_fire_department,
          label: 'Tage Serie',
          value: '${stats.currentStreak}',
        ),
        const SizedBox(width: 7),
        _StatTile(
          icon: Icons.emoji_events,
          label: 'Beste Serie',
          value: '${stats.bestStreak}',
        ),
        const SizedBox(width: 7),
        _StatTile(
          icon: Icons.calendar_today,
          label: 'Aktive Tage',
          value: '${stats.activeDays}',
        ),
        const SizedBox(width: 7),
        _StatTile(
          icon: Icons.bolt,
          label: 'Heute',
          value: '$todayCount',
        ),
      ],
    );
  }
}

/// Ein Statistik-Kästchen (Icon, Wert, Label) — Muster wie `_StatItem` im
/// Hero-Banner der Startseite.
class _StatTile extends StatelessWidget {
  const _StatTile({
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
            Text(label, style: AppTheme.secondaryStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// „Heute"-Karte mit den drei Detail-Zählern (Wörter / Quiz / Lektionen).
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});

  final StudyDayActivity today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heute', style: AppTheme.headingStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              _TodayItem(
                icon: Icons.menu_book,
                label: 'Wörter angesehen',
                value: '${today.wordsViewed}',
              ),
              const SizedBox(width: 8),
              _TodayItem(
                icon: Icons.quiz,
                label: 'Quiz-Antworten',
                value: '${today.quizAnswers}',
              ),
              const SizedBox(width: 8),
              _TodayItem(
                icon: Icons.flag,
                label: 'Lektionen bestanden',
                value: '${today.lessonsCompleted}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ein Zähler-Eintrag in der „Heute"-Karte (Icon + Wert + Label).
class _TodayItem extends StatelessWidget {
  const _TodayItem({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(value, style: AppTheme.titleStyle(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.secondaryStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

/// Karte mit der GitHub-Style-Heatmap der letzten [StatsTab.heatmapWeeks]
/// Wochen (Zeilen = Wochentage Mo–So, Spalten = Wochen, Farbe = Intensität).
class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.activityByDate});

  final Map<String, int> activityByDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deine Lernaktivität', style: AppTheme.headingStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            'Letzte ${StatsTab.heatmapWeeks} Wochen — jeden Tag eine Zelle',
            style: AppTheme.secondaryStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildGrid(),
          const SizedBox(height: 10),
          const _Legend(),
        ],
      ),
    );
  }

  /// 7×16-Zeilen-Grid: links die Wochentags-Beschriftung, rechts die Wochen-
  /// Spalten (neueste Woche ganz rechts). Beginnt am Montag der ersten Woche,
  /// endet mit der Woche von heute.
  Widget _buildGrid() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final firstDay = todayDate.subtract(
      Duration(days: StatsTab.heatmapDays - 1),
    );
    final gridStart = firstDay.subtract(
      Duration(days: firstDay.weekday - 1),
    );
    final todayKey = DatabaseHelper.studyDateKey(todayDate);
    const rowLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            for (final label in rowLabels)
              SizedBox(
                width: 18,
                child: Text(label, style: AppTheme.secondaryStyle(fontSize: 9)),
              ),
          ],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              for (var week = 0; week < StatsTab.heatmapWeeks; week++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Column(
                    children: [
                      for (var row = 0; row < 7; row++)
                        _buildCell(
                          gridStart.add(Duration(days: week * 7 + row)),
                          todayKey,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCell(DateTime day, String todayKey) {
    final dateKey = DatabaseHelper.studyDateKey(day);
    final count = activityByDate[dateKey] ?? 0;
    final cell = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _heatColor(count),
        borderRadius: BorderRadius.circular(4),
        border: dateKey == todayKey
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: count > 0
          ? Tooltip(
              message: '$dateKey · $count Aktivitäten',
              child: cell,
            )
          : cell,
    );
  }

  /// Farb-Skala der Heatmap: ganz dunkel = inaktiv, über drei Blau-Stufen bis
  /// Gold für sehr aktive Tage.
  static Color _heatColor(int count) {
    if (count <= 0) {
      return const Color(0xFF20262F);
    }
    if (count <= 2) {
      return AppColors.primary.withValues(alpha: 0.25);
    }
    if (count <= 5) {
      return AppColors.primary.withValues(alpha: 0.45);
    }
    if (count <= 10) {
      return AppColors.primary.withValues(alpha: 0.65);
    }
    if (count <= 20) {
      return AppColors.primary.withValues(alpha: 0.85);
    }
    return AppColors.gold;
  }
}

/// Legende unter der Heatmap: Farb-Schritte „wenig → viel“.
class _Legend extends StatelessWidget {
  const _Legend();

  static final List<int> steps = [0, 1, 3, 8, 20];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('0', style: AppTheme.secondaryStyle(fontSize: 9)),
        const SizedBox(width: 6),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _HeatmapCard._heatColor(step),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'wenig          viel',
            style: AppTheme.secondaryStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }
}