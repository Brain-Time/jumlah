import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_de.dart';

export 'app_localizations.dart';

/// H1 — Mehrsprachige UI (DE/EN/AR).
///
/// Bequemer Zugriff auf die generierten `AppLocalizations`. Wenn kein
/// `Localizations`-Kontext vorhanden ist (z. B. Widget-Tests, die Screens
/// ohne `AppLocalizations.delegate` pumpen), wird deterministisch auf die
/// deutsche Vorlage zurückgegriffen — alle bestehenden (deutschsprachigen)
/// Tests bleiben dadurch unverändert grün.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsDe();
}