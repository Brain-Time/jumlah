import 'package:flutter/material.dart';

/// Die zwei Design-Modi der App. Der aktive Modus wird über den
/// [ThemeNotifier] (`lib/providers/theme_provider.dart`) gehalten, in der SQLite-
/// `metadata`-Tabelle persistiert und beim App-Start wiederhergestellt.
enum ThemeKind {
  dark,
  light,
}

/// Dark/Light-Mode (Task „Dark/Light Mode Toggle“): Die neutralen Design-Tokens
/// sind kein fester Konstantensatz mehr, sondern werden aus der aktiven Palette
/// gelöst ([AppColors.use]). Die Akzentfarben [AppColors.primary], [AppColors.gold],
/// [AppColors.success] und [AppColors.error] sind modus-unabhängig und bleiben
/// echte `static const`-Felder (u. a. für `const`-Konstruktor-Aufrufe wie
/// `const Icon(..., color: AppColors.gold)`).
class AppColors {
  const AppColors._();

  // --- Modus-unabhängige Akzentfarben (identisch in Dark & Light). ---

  static const Color primary = Color(0xFF1B6CA8);
  static const Color gold = Color(0xFFC9A84C);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  // --- Aktive neutrale Palette (Default: Dark, entspricht dem bisherigen Look). ---

  static final _NeutralPalette _dark = _NeutralPalette(
    dark: const Color(0xFF0D1117),
    surface: const Color(0xFF161B22),
    surfaceElevated: const Color(0xFF1C2330),
    border: const Color(0xFF2A3242),
    textPrimary: const Color(0xFFF0F3F8),
    textSecondary: const Color(0xFF9AA7B8),
    textMuted: const Color(0xFF6B7686),
    heatEmpty: const Color(0xFF20262F),
  );

  static final _NeutralPalette _light = _NeutralPalette(
    dark: const Color(0xFFF7F8FA),
    surface: const Color(0xFFFFFFFF),
    surfaceElevated: const Color(0xFFF1F3F7),
    border: const Color(0xFFD9DEE6),
    textPrimary: const Color(0xFF1D2833),
    textSecondary: const Color(0xFF566070),
    textMuted: const Color(0xFF8A94A1),
    heatEmpty: const Color(0xFFE4E8EF),
  );

  static _NeutralPalette _active = _dark;

  /// Schaltet die neutralen Design-Tokens um. Wird vom App-Root
  /// (`main.dart`, `ref.watch(themeProvider)`) vor jedem Neuaufbau ausgeführt,
  /// sodass alle Screens die zur `MaterialApp` passende Palette lesen.
  static void use(ThemeKind kind) {
    _active = kind == ThemeKind.light ? _light : _dark;
  }

  static ThemeKind get activeTheme =>
      identical(_active, _light) ? ThemeKind.light : ThemeKind.dark;

  /// Hintergrund-Farbe der App (`Scaffold`-Fläche, App-Bar).
  static Color get dark => _active.dark;

  /// Standard-Kartenfläche.
  static Color get surface => _active.surface;

  /// Eine Ebene über `surface` (hervorgehobene Karten, Chip-Hintergründe).
  static Color get surfaceElevated => _active.surfaceElevated;

  /// Dezente Trenn- und Rahmenlinien.
  static Color get border => _active.border;

  /// Haupt-Textfarbe (überschreibt hartkodierte `Colors.white`-Auszeichnungen).
  static Color get textPrimary => _active.textPrimary;

  /// Sekundär-Text (Untertitel, Hinweise).
  static Color get textSecondary => _active.textSecondary;

  /// Gedämpfte Texte (Übersetzungs-/Transliterations-Nebenzeilen).
  static Color get textMuted => _active.textMuted;

  /// Leere Statistik-Heatmap-Zelle (`stats_screen.dart`).
  static Color get heatEmpty => _active.heatEmpty;
}

/// Wert-Halter der modus-abhängigen Neutral-Töne (siehe [AppColors]).
class _NeutralPalette {
  const _NeutralPalette({
    required this.dark,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.heatEmpty,
  });

  final Color dark;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color heatEmpty;
}

/// Design-Ebene (Task UI-1): zentrale, konsistente Styling-Helfer, damit
/// Screens einheitlich wirken statt jedes Mal flache `alpha: 0.05`-Karten
/// und Einzel-TextStyles zu verdrahten.
class AppTheme {
  const AppTheme._();

  /// Muss zusammen mit `Directionality(textDirection: TextDirection.rtl, ...)`
  /// verwendet werden, wenn arabischer Text dargestellt wird.
  static const String arabicFontFamily = 'Amiri';

  static const double cardRadius = 16;
  static const double cardPadding = 18;
  static const EdgeInsets cardPaddingAll = EdgeInsets.all(cardPadding);

  /// Einheitliche Karten-Dekoration: dezente Fläche + Border + weicher
  /// Schatten — statt flacher, konturloser Flächen.
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    BorderRadius? borderRadius,
    BoxShadow? shadow,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: borderRadius ?? BorderRadius.circular(cardRadius),
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: [
        shadow ?? const BoxShadow(color: Color(0x22000000), blurRadius: 12),
      ],
    );
  }

  /// Überschrift-Stil für Karten/Seiten (klar hierarchisch gegenüber Fließtext).
  static TextStyle headingStyle({double fontSize = 20, Color? color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle titleStyle({double fontSize = 16, Color? color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle bodyStyle({double fontSize = 14, Color? color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle secondaryStyle({
    double fontSize = 13,
    Color? color,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.textSecondary,
      fontStyle: fontStyle,
    );
  }

  /// Dark-Theme (bisheriger Standard-Look der App).
  static ThemeData get darkTheme => _themeData(Brightness.dark);

  /// Light-Theme (Dark/Light-Mode): gleiche Markenfarben und -Schablonen, aber
  /// helle Flächen/Chrome und dunkle Text-Neutrals aus der Light-Palette.
  static ThemeData get lightTheme => _themeData(Brightness.light);

  static ThemeData _themeData(Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final isDark = brightness == Brightness.dark;
    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? AppColors._dark.dark : AppColors._light.dark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        error: AppColors.error,
        surface: isDark ? AppColors._dark.surface : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors._dark.dark : AppColors._light.dark,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: isDark
              ? AppColors._dark.textPrimary
              : AppColors._light.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: isDark ? AppColors._dark.border : AppColors._light.border,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark
              ? AppColors._dark.textPrimary
              : AppColors._light.textPrimary,
          side: BorderSide(
            color: isDark ? AppColors._dark.border : AppColors._light.border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Für arabische Wörter/Sätze: größere Schriftgröße, Amiri-Font. Ohne explizite
  /// [color] wird die aktive Haupt-Textfarbe der Palette verwendet, damit der
  /// Text in Dark- wie Light-Mode lesbar bleibt (bisher hart weiß).
  static TextStyle arabicTextStyle({
    double fontSize = 28,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      fontFamily: arabicFontFamily,
      fontSize: fontSize,
      color: color ?? AppColors.textPrimary,
      fontWeight: fontWeight,
    );
  }
}
