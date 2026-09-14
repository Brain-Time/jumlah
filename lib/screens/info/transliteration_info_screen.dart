import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class _LetterEntry {
  const _LetterEntry(this.arabic, this.symbol, this.note);

  final String arabic;
  final String symbol;
  final String note;
}

const List<_LetterEntry> _letters = [
  _LetterEntry('ء', 'ʾ', 'Stimmritzenverschluss (Hamza) — der Knacklaut vor Vokalen wie in „Verein“'),
  _LetterEntry('ا', 'ā', 'langes „a“ wie in „Vater“'),
  _LetterEntry('ب', 'b', 'wie deutsches „b“'),
  _LetterEntry('ت', 't', 'wie deutsches „t“'),
  _LetterEntry('ث', 'ṯ', 'stimmloses „th“ wie engl. „think“'),
  _LetterEntry('ج', 'ǧ', 'wie „dsch“ in „Dschungel“'),
  _LetterEntry('ح', 'ḥ', 'gepresster Rachen-h-Laut, schärfer als deutsches „h“'),
  _LetterEntry('خ', 'ḫ', 'wie „ch“ in „Bach“'),
  _LetterEntry('د', 'd', 'wie deutsches „d“'),
  _LetterEntry('ذ', 'ḏ', 'stimmhaftes „th“ wie engl. „this“'),
  _LetterEntry('ر', 'r', 'gerolltes „r“'),
  _LetterEntry('ز', 'z', 'stimmhaftes „s“ wie in „Sonne“'),
  _LetterEntry('س', 's', 'stimmloses „s“ wie in „Wasser“'),
  _LetterEntry('ش', 'š', 'wie deutsches „sch“'),
  _LetterEntry('ص', 'ṣ', 'emphatisches (velarisiertes) „s“'),
  _LetterEntry('ض', 'ḍ', 'emphatisches „d“'),
  _LetterEntry('ط', 'ṭ', 'emphatisches „t“'),
  _LetterEntry('ظ', 'ẓ', 'emphatisches „th“ (wie ذ, aber velarisiert)'),
  _LetterEntry('ع', 'ʿ', 'stimmhafter Rachenlaut ohne deutsches Äquivalent (ʿAin)'),
  _LetterEntry('غ', 'ġ', 'wie das französische „r“ (Reibelaut im Rachen)'),
  _LetterEntry('ف', 'f', 'wie deutsches „f“'),
  _LetterEntry('ق', 'q', 'wie „k“, aber tief im Rachen gebildet (Uvular)'),
  _LetterEntry('ك', 'k', 'wie deutsches „k“'),
  _LetterEntry('ل', 'l', 'wie deutsches „l“'),
  _LetterEntry('م', 'm', 'wie deutsches „m“'),
  _LetterEntry('ن', 'n', 'wie deutsches „n“'),
  _LetterEntry('ه', 'h', 'wie deutsches „h“'),
  _LetterEntry('و', 'w / ū', 'Halbvokal „w“ oder langes „u“'),
  _LetterEntry('ي', 'y / ī', 'Halbvokal „j“ oder langes „i“'),
  _LetterEntry('ة', '-a / -at', 'Tāʾ marbūṭa: „a“ am Wortende, vor Folgewort oft „-at“'),
  _LetterEntry('ى', 'ā', 'Alif maqṣūra: langes „a“ am Wortende'),
];

const List<_LetterEntry> _diacritics = [
  _LetterEntry('َ', 'a', 'Fatha — kurzes „a“'),
  _LetterEntry('ِ', 'i', 'Kasra — kurzes „i“'),
  _LetterEntry('ُ', 'u', 'Damma — kurzes „u“'),
  _LetterEntry('ْ', '(kein Vokal)', 'Sukun — der Konsonant trägt keinen Vokal'),
  _LetterEntry('ّ', '(Verdopplung)', 'Shadda — der Konsonant wird doppelt gesprochen'),
];

/// Erklärt die in der App verwendete wissenschaftliche Transliteration nach
/// DIN 31635 — erreichbar über das Info-Icon im Learn Screen (nur bei
/// A1/A2, siehe `core/word_groups.dart#showsTransliteration`).
class TransliterationInfoScreen extends StatelessWidget {
  const TransliterationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transliteration (DIN 31635)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Die arabische Umschrift in dieser App folgt DIN 31635, dem '
              'wissenschaftlichen Standard der Arabistik. Sie zeigt exakt, '
              'wie ein Wort geschrieben und gesprochen wird — inklusive '
              'Laute, die es im Deutschen nicht gibt. Ab Stufe B1 wird die '
              'Umschrift bewusst nicht mehr angezeigt, da du dann die '
              'arabische Schrift direkt lesen sollst.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 24),
            const Text(
              'Buchstaben',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _letters) _LetterRow(entry: entry),
            const SizedBox(height: 24),
            const Text(
              'Kurzvokale & Zeichen',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _diacritics) _LetterRow(entry: entry),
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
