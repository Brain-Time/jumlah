import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jumlah/screens/info/info_screen.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Test-Fake für `package:url_launcher`: zeichnet alle Launch-Aufrufe auf,
/// statt einen echten Browser zu öffnen.
class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];
  final List<LaunchOptions> launchOptions = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    launchOptions.add(options);
    return true;
  }
}

void main() {
  late _FakeUrlLauncherPlatform fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  testWidgets('InfoScreen zeigt beide Einstellungs-Eintraege', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    // Info-Liste ist höher als die Standard-Test-Fläche (800×600); größeres
    // Fenster, damit auch der untere Einstellungs-Eintrag aufgebaut wird.
    await tester.binding.setSurfaceSize(Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: InfoScreen())),
      );
      await tester.pump();
    });

    expect(find.text('Info'), findsWidgets);
    expect(find.text('Entwickler unterstützen ☕'), findsOneWidget);
    expect(find.text('Impressum & Datenschutz'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Support-Eintrag oeffnet die Ko-fi-URL im Browser', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.binding.setSurfaceSize(Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: InfoScreen())),
      );
      await tester.pump();

      await tester.tap(find.text('Entwickler unterstützen ☕'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(fakeLauncher.launchedUrls, [InfoScreen.supportUrl]);
    expect(fakeLauncher.launchOptions, hasLength(1));
    // Standard-Modus: Android oeffnet den Standard-Browser, iOS den sicheren
    // SafariViewController (In-App-Browser).
    expect(
      fakeLauncher.launchOptions.single.mode,
      PreferredLaunchMode.platformDefault,
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Rechts-Eintrag oeffnet die Impressum-URL', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.binding.setSurfaceSize(Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: InfoScreen())),
      );
      await tester.pump();

      await tester.tap(find.text('Impressum & Datenschutz'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(fakeLauncher.launchedUrls, [InfoScreen.legalUrl]);
    expect(fakeLauncher.launchOptions, hasLength(1));

    debugDefaultTargetPlatformOverride = null;
  });
}