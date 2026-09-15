import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';

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
      appBar: AppBar(title: Text(context.l10n.tabStats)),
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
                  context.l10n.noActivityTitle,
                  style: AppTheme.titleStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.noActivityBody,
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
          label: context.l10n.currentStreak,
          value: '${stats.currentStreak}',
        ),
        const SizedBox(width: 7),
        _StatTile(
          icon: Icons.emoji_events,
          label: context.l10n.bestStreak,
          value: '${stats.bestStreak}',
        ),
        const SizedBox(width: 7),
        _StatTile(
          icon: Icons.calendar_today,
          label: context.l10n.activeDays,
          value: '${stats.activeDays}',
        ),
        const SizedBox(width: 7),
        _StatTile(
          icon: Icons.bolt,
          label: context.l10n.today,
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
          Text(context.l10n.today, style: AppTheme.headingStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              _TodayItem(
                icon: Icons.menu_book,
                label: context.l10n.wordsViewed,
                value: '${today.wordsViewed}',
              ),
              const SizedBox(width: 8),
              _TodayItem(
                icon: Icons.quiz,
                label: context.l10n.quizAnswers,
                value: '${today.quizAnswers}',
              ),
              const SizedBox(width: 8),
              _TodayItem(
                icon: Icons.flag,
                label: context.l10n.lessonsCompleted,
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
          Text(context.l10n.heatmapTitle, style: AppTheme.headingStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            context.l10n.heatmapSubtitle(StatsTab.heatmapWeeks),
            style: AppTheme.secondaryStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildGrid(context),
          const SizedBox(height: 10),
          const _Legend(),
        ],
      ),
    );
  }

  /// 7×16-Zeilen-Grid: links die Wochentags-Beschriftung, rechts die Wochen-
  /// Spalten (neueste Woche ganz rechts). Beginnt am Montag der ersten Woche,
  /// endet mit der Woche von heute.
  Widget _buildGrid(BuildContext context) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final firstDay = todayDate.subtract(
      Duration(days: StatsTab.heatmapDays - 1),
    );
    final gridStart = firstDay.subtract(
      Duration(days: firstDay.weekday - 1),
    );
    final todayKey = DatabaseHelper.studyDateKey(todayDate);
    final l10n = context.l10n;
    final rowLabels = [
      l10n.weekdayMo,
      l10n.weekdayDi,
      l10n.weekdayMi,
      l10n.weekdayDo,
      l10n.weekdayFr,
      l10n.weekdaySa,
      l10n.weekdaySo,
    ];

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
                          context,
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

  Widget _buildCell(DateTime day, String todayKey, BuildContext context) {
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
              message: context.l10n.heatmapTooltip(dateKey, count),
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
            '${context.l10n.legendLittle}    ${context.l10n.legendMuch}',
            style: AppTheme.secondaryStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }
}