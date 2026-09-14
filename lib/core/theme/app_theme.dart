import 'package:flutter/material.dart';

/// Design-System-Farben, siehe README.md Abschnitt "Design-System".
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF1B6CA8);
  static const Color gold = Color(0xFFC9A84C);
  static const Color dark = Color(0xFF0D1117);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  /// Zusätzliche, fein abgestufte Neutral-/Oberflächen-Töne (Task UI-1:
  /// professionellere Ebenen und Lesbarkeit statt nur `Colors.white70`).
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF1C2330);
  static const Color border = Color(0xFF2A3242);
  static const Color textPrimary = Color(0xFFF0F3F8);
  static const Color textSecondary = Color(0xFF9AA7B8);
  static const Color textMuted = Color(0xFF6B7686);
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

  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.dark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: AppColors.border,
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
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Für arabische Wörter/Sätze: größere Schriftgröße, Amiri-Font.
  static TextStyle arabicTextStyle({
    double fontSize = 28,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      fontFamily: arabicFontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }
}
