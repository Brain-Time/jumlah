import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';

class _LetterEntry {
  const _LetterEntry(this.arabic, this.symbol, this.note);

  final String arabic;
  final String symbol;
  final String note;
}

/// Buchstaben-Tabelle in der aktiven UI-Sprache (H1 — Mehrsprachige UI):
/// die Erklärungen sind Übersetzungs-Keys, die Schriftzeichen bleiben fix.
List<_LetterEntry> _letters(AppLocalizations l10n) => [
      _LetterEntry('ء', 'ʾ', l10n.tlHamza),
      _LetterEntry('ا', 'ā', l10n.tlAlef),
      _LetterEntry('ب', 'b', l10n.tlBa),
      _LetterEntry('ت', 't', l10n.tlTa),
      _LetterEntry('ث', 'ṯ', l10n.tlTha),
      _LetterEntry('ج', 'ǧ', l10n.tlJim),
      _LetterEntry('ح', 'ḥ', l10n.tlHa),
      _LetterEntry('خ', 'ḫ', l10n.tlKha),
      _LetterEntry('د', 'd', l10n.tlDal),
      _LetterEntry('ذ', 'ḏ', l10n.tlDhal),
      _LetterEntry('ر', 'r', l10n.tlRa),
      _LetterEntry('ز', 'z', l10n.tlZay),
      _LetterEntry('س', 's', l10n.tlSin),
      _LetterEntry('ش', 'š', l10n.tlShin),
      _LetterEntry('ص', 'ṣ', l10n.tlSad),
      _LetterEntry('ض', 'ḍ', l10n.tlDad),
      _LetterEntry('ط', 'ṭ', l10n.tlTaEmph),
      _LetterEntry('ظ', 'ẓ', l10n.tlZa),
      _LetterEntry('ع', 'ʿ', l10n.tlAyn),
      _LetterEntry('غ', 'ġ', l10n.tlGhayn),
      _LetterEntry('ف', 'f', l10n.tlFa),
      _LetterEntry('ق', 'q', l10n.tlQaf),
      _LetterEntry('ك', 'k', l10n.tlKaf),
      _LetterEntry('ل', 'l', l10n.tlLam),
      _LetterEntry('م', 'm', l10n.tlMim),
      _LetterEntry('ن', 'n', l10n.tlNun),
      _LetterEntry('ه', 'h', l10n.tlHeh),
      _LetterEntry('و', 'w / ū', l10n.tlWaw),
      _LetterEntry('ي', 'y / ī', l10n.tlYa),
      _LetterEntry('ة', '-a / -at', l10n.tlTaMarbuta),
      _LetterEntry('ى', 'ā', l10n.tlAlifMaqsura),
    ];

List<_LetterEntry> _diacritics(AppLocalizations l10n) => [
      _LetterEntry('َ', 'a', l10n.tdFatha),
      _LetterEntry('ِ', 'i', l10n.tdKasra),
      _LetterEntry('ُ', 'u', l10n.tdDamma),
      _LetterEntry('ْ', l10n.tdSukunSymbol, l10n.tdSukun),
      _LetterEntry('ّ', l10n.tdShaddaSymbol, l10n.tdShadda),
    ];

/// Erklärt die in der App verwendete wissenschaftliche Transliteration nach
/// DIN 31635 — erreichbar über das Info-Icon im Learn Screen (nur bei
/// A1/A2, siehe `core/word_groups.dart#showsTransliteration`).
class TransliterationInfoScreen extends StatelessWidget {
  const TransliterationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transliterationTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.transliterationIntro,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.lettersHeading,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _letters(l10n)) _LetterRow(entry: entry),
            const SizedBox(height: 24),
            Text(
              l10n.diacriticsHeading,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _diacritics(l10n)) _LetterRow(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  const _LetterRow({required this.entry});

  final _LetterEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                entry.arabic,
                style: AppTheme.arabicTextStyle(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              entry.symbol,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.note,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
