import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';

/// Info-/Rechts-Menü der App: Einstellungs-Liste mit UI-Sprachwahl (H1 —
/// Mehrsprachige UI) sowie zwei Einträgen — Support (Ko-fi-Spende) und
/// Impressum & Datenschutz. Die Link-Einträge öffnen beim Antippen ihre URL
/// über `package:url_launcher` async und modusabhängig: auf Android/Desktop
/// den Standard-Browser, auf iOS den sicheren In-App-Browser
/// (SafariViewController).
///
/// Erreichbar über den vierten Tab „Info“ in der Bottom Navigation
/// (siehe `home_screen.dart`). Das Design greift ausschließlich auf die
/// zentralen Design-Tokens zu (AppColors/AppTheme) und zieht damit auch bei
/// einer späteren Light-Theme-Variante automatisch mit.
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  /// Ziel-URL des Support-Eintrags (freiwillige Spende).
  static const String supportUrl = 'https://ko-fi.com/braintime';

  /// Ziel-URL des Rechts-Eintrags (Impressum & Datenschutz).
  static const String legalUrl = 'https://derman.dev/impressum';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLocale = ref.watch(localeProvider);
    final activeTheme = ref.watch(themeProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabInfo)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.supportLegalHeading,
                  style: AppTheme.headingStyle(fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.supportLegalBody,
                  style: AppTheme.secondaryStyle(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // H1 — Sprachwahl: wechselt die UI-Sprache sofort und global.
            _LanguageCard(
              activeLocale: activeLocale,
              onSelect: (locale) {
                ref.read(localeProvider.notifier).setLocale(locale);
              },
            ),
            const SizedBox(height: 14),
            // Dark/Light-Mode: wechselt das App-Design sofort und global.
            _ThemeCard(
              activeTheme: activeTheme,
              onSelect: (kind) {
                ref.read(themeProvider.notifier).setTheme(kind);
              },
            ),
            const SizedBox(height: 14),
            Container(
              decoration: AppTheme.cardDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _InfoLinkTile(
                    icon: Icons.coffee,
                    accent: AppColors.gold,
                    title: l10n.supportTitle,
                    subtitle: l10n.supportSubtitle,
                    url: InfoScreen.supportUrl,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _InfoLinkTile(
                    icon: Icons.gavel,
                    accent: AppColors.primary,
                    title: l10n.legalTitle,
                    subtitle: l10n.legalSubtitle,
                    url: InfoScreen.legalUrl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// H1 — Karte für die UI-Sprachwahl: drei antippbare Einträge (Deutsch /
/// English / العربية); die aktive Sprache ist markiert und wird bei Auswahl
/// sofort über den [localeProvider] umgestellt.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.activeLocale, required this.onSelect});

  final Locale activeLocale;
  final ValueChanged<Locale> onSelect;

  /// Die von der App unterstützten Sprachen mit muttersprachlichem Namen.
  static const List<MapEntry<Locale, String>> _options = [
    MapEntry(Locale('de'), 'Deutsch'),
    MapEntry(Locale('en'), 'English'),
    MapEntry(Locale('ar'), 'العربية'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceElevated,
        borderColor: AppColors.primary.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.languageHeading,
            style: AppTheme.titleStyle(fontSize: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.languageBody,
            style: AppTheme.secondaryStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final option in _options)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                option.key.languageCode == 'ar'
                    ? Icons.translate
                    : Icons.language,
                color: activeLocale.languageCode == option.key.languageCode
                    ? AppColors.gold
                    : AppColors.textSecondary,
              ),
              title: Text(
                option.value,
                style: TextStyle(
                  color: activeLocale.languageCode == option.key.languageCode
                      ? AppColors.gold
                      : AppColors.textPrimary,
                  fontWeight:
                      activeLocale.languageCode == option.key.languageCode
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: activeLocale.languageCode == option.key.languageCode
                  ? const Icon(Icons.check, color: AppColors.gold, size: 20)
                  : null,
              onTap: () => onSelect(option.key),
            ),
        ],
      ),
    );
  }
}

/// Dark/Light-Mode — Karte für das App-Design: zwei antippbare Einträge
/// (Dunkel/Hell); der aktive Modus ist markiert und wird bei Auswahl sofort
/// über den [themeProvider] umgestellt (persistiert in SQLite).
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.activeTheme, required this.onSelect});

  final ThemeKind activeTheme;
  final ValueChanged<ThemeKind> onSelect;

  /// Die angebotenen Design-Modi (Reihenfolge = Anzeige-Reihenfolge).
  static const List<ThemeKind> _options = [ThemeKind.dark, ThemeKind.light];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceElevated,
        borderColor: AppColors.primary.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.themeHeading,
            style: AppTheme.titleStyle(fontSize: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.themeBody,
            style: AppTheme.secondaryStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final option in _options)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                option == ThemeKind.dark ? Icons.dark_mode : Icons.light_mode,
                color: activeTheme == option
                    ? AppColors.gold
                    : AppColors.textSecondary,
              ),
              title: Text(
                option == ThemeKind.dark ? l10n.themeDark : l10n.themeLight,
                style: TextStyle(
                  color: activeTheme == option
                      ? AppColors.gold
                      : AppColors.textPrimary,
                  fontWeight: activeTheme == option
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: activeTheme == option
                  ? const Icon(Icons.check, color: AppColors.gold, size: 20)
                  : null,
              onTap: () => onSelect(option),
            ),
        ],
      ),
    );
  }
}

/// Ein Eintrag der Einstellungs-Liste: Icon-Badge, Titel, Untertitel und
/// Chevron. Der gesamte Eintrag ist antippbar und öffnet [url] asynchron über
/// `package:url_launcher` (Standard-Browser bzw. iOS-In-App-Browser).
class _InfoLinkTile extends StatelessWidget {
  const _InfoLinkTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUrl(),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IconBadge(icon: icon, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.titleStyle(fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTheme.secondaryStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Öffnet [url] bewusst ohne Blockade: Der Standard-Launch-Modus öffnet
  /// Web-URLs auf iOS im sicheren SafariViewController, auf Android/Desktop
  /// im System-Browser. Fehler (z. B. kein verfügbarer Browser) werden still
  /// geschluckt, damit das Menü bedienbar bleibt.
  Future<void> _openUrl() async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } catch (_) {
      // Absichtlich leer — siehe Doc-Kommentar oben.
    }
  }
}

/// Kleines Icon-Badge im Karten-Stil (analog zu `_BlockIcon` im Home-Screen).
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}