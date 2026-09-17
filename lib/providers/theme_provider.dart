import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';
import '../core/theme/app_theme.dart';

/// Dark/Light-Mode (Task „Dark/Light Mode Toggle“): hält den aktuellen
/// Design-Modus der App.
///
/// Standard ist Dunkel (bestehendes Verhalten, entspricht der bisherigen
/// durchgängig dunklen App). Die Wahl wird beim ersten Start über die
/// bestehende SQLite-`metadata`-Tabelle wiederhergestellt
/// ([ThemeNotifier.restoreSaved]) und bei jeder Änderung dort persistiert
/// ([ThemeNotifier.setTheme]) — analog zu `locale_provider.dart`. Die eigentliche
/// Farb-Umschaltung (`AppColors.use`) übernimmt das App-Root (`main.dart`)
/// beim Neuaufbau aus dem `ref.watch(themeProvider)`.
class ThemeNotifier extends Notifier<ThemeKind> {
  @override
  ThemeKind build() => ThemeKind.dark;

  /// Stellt den zuletzt gespeicherten Design-Modus aus der Datenbank wieder
  /// her. Wird einmalig beim App-Start aufgerufen (siehe `main.dart`), während
  /// [ThemeNotifier.build] synchron mit Dunkel startet.
  Future<void> restoreSaved() async {
    final mode = await DatabaseHelper.instance.getThemeMode();
    if (mode == 'light' && state != ThemeKind.light) {
      state = ThemeKind.light;
    }
  }

  /// Wechselt den Design-Modus sofort und persistiert ihn fire-and-forget.
  Future<void> setTheme(ThemeKind kind) async {
    if (kind == state) {
      return;
    }
    state = kind;
    await DatabaseHelper.instance.saveThemeMode(
      kind == ThemeKind.light ? 'light' : 'dark',
    );
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeKind>(
  ThemeNotifier.new,
);