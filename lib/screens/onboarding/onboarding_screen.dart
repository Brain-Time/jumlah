import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../info/info_screen.dart';

/// First-Run-Onboarding (einmalig, vor der Startseite): erklärt dem Nutzer
/// beim allerersten Start kurz, was Jumlah ist und wie das Lernen funktioniert,
/// und weist **am Ende** auf die (freiwillige) Unterstützung hin (Ko-fi,
/// gleiche URL wie im Info-Menü). Wird nur angezeigt, solange das
/// `onboarding_seen`-Flag in der `metadata`-Tabelle nicht gesetzt ist
/// (`DatabaseHelper.isOnboardingSeen`); „Los geht’s“ markiert es und
/// navigiert per `pushReplacement` zur Startseite (`HomeScreen`).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            // Kopf: Logo + Begrüßung.
            Center(
              child: Image.asset('assets/branding/jumla_logo.png', width: 120),
            ),
            const SizedBox(height: 20),
            Text(
              'Willkommen bei Jumlah',
              textAlign: TextAlign.center,
              style: AppTheme.headingStyle(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              'Lerne klassisches Arabisch (Fusha / Qur’anisch) — Schritt für '
              'Schritt, offline & kostenlos, in deinem eigenen Tempo.',
              textAlign: TextAlign.center,
              style: AppTheme.secondaryStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Motivation: warum sich das tägliche Lernen lohnt.
            const _OnboardingSection(
              icon: Icons.local_fire_department,
              accent: AppColors.gold,
              title: 'Bleib am Ball 🔥',
              description:
                  'Konsequenz schlägt Talent: Schon 10 Minuten am Tag bringen '
                  'dich Woche für Woche weiter — von den ersten Verben bis zu '
                  'seltenen koranischen Ausdrücken.',
            ),
            const SizedBox(height: 16),
            Text(
              'Das erwartet dich:',
              style: AppTheme.titleStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const _OnboardingSection(
              icon: Icons.menu_book,
              accent: AppColors.gold,
              title: 'Klassisches Arabisch',
              description:
                  'Die 500 häufigsten Wörter des klassischen Arabisch — jedes '
                  'mit 3 echten Kontext-Sätzen, Wurzel-Familie, Masdar und '
                  'DIN-31635-Umschrift.',
            ),
            const _OnboardingSection(
              icon: Icons.headphones,
              accent: AppColors.primary,
              title: 'Audio-Aussprache',
              description:
                  'Jeder Kontext-Satz wird dir vorgelesen — lokal gebündelte '
                  'Audios, ganz ohne Internet.',
            ),
            const _OnboardingSection(
              icon: Icons.school,
              accent: AppColors.primary,
              title: 'Lektion für Lektion mit Prüfung',
              description:
                  '50 Lektionen à 10 Wörter. Nach jeder Lektion folgt die '
                  'Prüfung in 6 Stufen (Wort, Sätze, Audio, Geschichte) mit '
                  'höchstens 3 Fehlern — wer besteht, schaltet frei.',
            ),
            const _OnboardingSection(
              icon: Icons.search,
              accent: AppColors.success,
              title: 'Offline-Wörterbuch',
              description:
                  'Suche arabische Wörter und Sätze — harakat- und '
                  'umschrift-insensitiv, damit du auch ohne Diakritik findest.',
            ),
            const _OnboardingSection(
              icon: Icons.insights,
              accent: AppColors.success,
              title: 'Lernstatistik',
              description:
                  'Behalte deine Serie 🔥, aktiven Tage und eine '
                  '16-Wochen-Aktivitäts-Heatmap im Überblick.',
            ),
            const _OnboardingSection(
              icon: Icons.autorenew,
              accent: AppColors.gold,
              title: 'Wiederholungen',
              description:
                  'Fällige Wörter werden dir nach dem SM-2-Lernabstand erneut '
                  'vorgelegt — für langfristigen Wortschatz.',
            ),
            const _OnboardingSection(
              icon: Icons.offline_bolt,
              accent: AppColors.success,
              title: 'Offline & kostenlos',
              description:
                  'Alles funktioniert ohne Internet, dein Fortschritt bleibt '
                  'auf deinem Gerät — und die App ist komplett kostenlos.',
            ),
            const SizedBox(height: 8),
            // Die App wird aktiv weiterentwickelt.
            Container(
              padding: const EdgeInsets.all(AppTheme.cardPadding),
              decoration: AppTheme.cardDecoration(
                borderColor: AppColors.primary.withValues(alpha: 0.45),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.rocket_launch, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jumlah wird aktiv weiterentwickelt',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Neue Lektionen, Sprachniveaus und Funktionen folgen '
                          'regelmäßig — bleib dran und wachse mit der App mit.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Support-Hinweis am Ende (Nutzer-Vorgabe).
            Container(
              padding: const EdgeInsets.all(AppTheme.cardPadding),
              decoration: AppTheme.cardDecoration(
                borderColor: AppColors.gold.withValues(alpha: 0.35),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unterstütze die Entwicklung',
                    style: AppTheme.titleStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jumlah ist kostenlos. Wenn dir die App gefällt, kannst du '
                    'die Entwicklung freiwillig unterstützen:',
                    style: AppTheme.secondaryStyle(),
                  ),
                  const SizedBox(height: 14),
                  _SupportTile(onTap: _openSupport),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _finish(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Los geht’s'),
            ),
          ],
        ),
      ),
    );
  }

  /// Öffnet die Ko-fi-Spende-URL (wie im Info-Menü) im Standard-Browser
  /// bzw. iOS-In-App-Browser. Fehler werden still geschluckt.
  Future<void> _openSupport() async {
    try {
      await launchUrl(
        Uri.parse(InfoScreen.supportUrl),
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {
      // Absichtlich leer — siehe Doc-Kommentar oben.
    }
  }

  /// Schließt das Onboarding ab und öffnet die Startseite
  /// (`pushReplacement`, damit „Zurück“ nicht wieder ins Onboarding führt).
  /// Das `onboarding_seen`-Flag wird bereits beim Anzeigen vom SplashScreen
  /// gesetzt (mark-on-show, siehe splash_screen.dart) — hier passiert bewusst
  /// keine DB-I/O im Tap-Handler.
  void _finish(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
}

/// Eine erklärende Sektion im Onboarding: Icon-Badge, Titel und Beschreibung
/// in der etablierten Karten-Optik (`AppTheme.cardDecoration`).
class _OnboardingSection extends StatelessWidget {
  const _OnboardingSection({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.titleStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.secondaryStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Klickbarer Ko-fi-Support-Tile (analog zum Info-Menü), hier bewusst kompakt
/// mit eigenem Untertitel.
class _SupportTile extends StatelessWidget {
  const _SupportTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.coffee, color: AppColors.gold, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Entwickler unterstützen ☕',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

