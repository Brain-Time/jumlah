import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';

/// H1 — Mehrsprachige UI (DE/EN/AR): hält die aktuelle UI-Sprache der App.
///
/// Standard ist Deutsch (bestehendes Verhalten). Die Wahl wird beim ersten
/// Start über die bestehende SQLite-`metadata`-Tabelle wiederhergestellt
/// ([LocaleNotifier.restoreSaved]) und bei jeder Änderung dort persistiert
/// ([LocaleNotifier.setLocale]) — dadurch bleibt die App offline-fähig und
/// braucht kein zusätzliches Paket für die Persistenz.
class LocaleNotifier extends Notifier<Locale> {
  /// Von der App unterstützte UI-Sprachen (Reihenfolge = Präferenz bei
  /// `MaterialApp.supportedLocales`).
  static const List<Locale> supportedLocales = [
    Locale('de'),
    Locale('en'),
    Locale('ar'),
  ];

  @override
  Locale build() => const Locale('de');

  /// Stellt die zuletzt gespeicherte Sprache aus der Datenbank wieder her.
  /// Wird einmalig beim App-Start aufgerufen (siehe `main.dart`), während
  /// [LocaleNotifier.build] synchron mit Deutsch startet.
  Future<void> restoreSaved() async {
    final code = await DatabaseHelper.instance.getLocaleCode();
    if (code == null || code == state.languageCode) {
      return;
    }
    final supported = supportedLocales.any((l) => l.languageCode == code);
    if (!supported) {
      return;
    }
    state = Locale(code);
  }

  /// Wechselt die UI-Sprache sofort und persistiert sie fire-and-forget.
  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == state.languageCode) {
      return;
    }
    state = locale;
    await DatabaseHelper.instance.saveLocaleCode(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);