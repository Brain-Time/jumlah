import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// Info-/Rechts-Menü der App: klassische Einstellungs-Liste mit zwei Einträgen
/// — Support (Ko-fi-Spende) und Impressum & Datenschutz. Beide öffnen beim
/// Antippen ihre URL über `package:url_launcher` asynchron und modusabhängig:
/// auf Android/Desktop den Standard-Browser, auf iOS den sicheren In-App-
/// Browser (SafariViewController).
///
/// Erreichbar über den vierten Tab „Info“ in der Bottom Navigation
/// (siehe `home_screen.dart`). Das Design greift ausschließlich auf die
/// zentralen Design-Tokens zu (AppColors/AppTheme) und zieht damit auch bei
/// einer späteren Light-Theme-Variante automatisch mit.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  /// Ziel-URL des Support-Eintrags (freiwillige Spende).
  static const String supportUrl = 'https://ko-fi.com/braintime';

  /// Ziel-URL des Rechts-Eintrags (Impressum & Datenschutz).
  static const String legalUrl = 'https://derman.dev/impressum';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support & Rechtliches',
                  style: AppTheme.headingStyle(fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unterstütze die Entwicklung oder rufe die gesetzlich '
                  'erforderlichen Angaben auf.',
                  style: AppTheme.secondaryStyle(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: AppTheme.cardDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _InfoLinkTile(
                    icon: Icons.coffee,
                    accent: AppColors.gold,
                    title: 'Entwickler unterstützen ☕',
                    subtitle: 'Freiwillige Spende über Ko-fi — '
                        'die App bleibt kostenlos.',
                    url: InfoScreen.supportUrl,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _InfoLinkTile(
                    icon: Icons.gavel,
                    accent: AppColors.primary,
                    title: 'Impressum & Datenschutz',
                    subtitle: 'Rechtliche Angaben und Datenschutzhinweise.',
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
              const Icon(
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