import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Splash Screen (Task E2): Logo mit Fade-in auf dunklem Hintergrund,
/// während im Hintergrund die Asset-Daten importiert werden
/// (`DatabaseHelper.reimportAssetDataIfVersionChanged`/`importXIfNeeded`,
/// zuvor in `main()` vor `runApp()` awaitet — dadurch blieb der Bildschirm
/// bis zum Abschluss des Imports einfach schwarz, siehe Task D1). Navigiert
/// danach per `pushReplacement` zu [HomeScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minDisplayDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    // Deferred, damit der erste Frame (Fade-in-Start) nicht durch die
    // async Arbeit verzögert wird.
    Future.microtask(_loadAndContinue);
  }

  Future<void> _loadAndContinue() async {
    final minDisplay = Future<void>.delayed(_minDisplayDuration);
    await Future.wait([_importData(), minDisplay]);
    if (!mounted) {
      return;
    }
    // Beim allerersten Start (onboarding_seen-Flag nicht gesetzt) geht es
    // nach dem Splash zunächst zum Erklär-Screen, sonst direkt zur Startseite.
    // Das Flag wird hier (im selben runAsync-Kontext wie der Asset-Import)
    // bereits beim Anzeigen gesetzt — das Onboarding erscheint damit exakt
    // einmal; „Los geht’s“ im Onboarding navigiert nur noch (keine DB-I/O im
    // Tap-Handler, siehe onboarding_screen.dart).
    final onboardingSeen = await DatabaseHelper.instance.isOnboardingSeen();
    if (!mounted) {
      return;
    }
    if (!onboardingSeen) {
      await DatabaseHelper.instance.markOnboardingSeen();
    }
    if (!mounted) {
      return;
    }
    final next = onboardingSeen
        ? const HomeScreen()
        : const OnboardingScreen();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  Future<void> _importData() async {
    final db = DatabaseHelper.instance;
    await db.reimportAssetDataIfVersionChanged();
    await db.importWordsIfNeeded();
    await db.importSentencesIfNeeded();
    await db.importRootsIfNeeded();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/branding/jumla_logo.png', width: 160),
              const SizedBox(height: 24),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  'جُمْلَة',
                  style: AppTheme.arabicTextStyle(
                    fontSize: 32,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Jumlah',
                style: TextStyle(color: Colors.white70, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
