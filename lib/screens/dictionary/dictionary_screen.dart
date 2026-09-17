import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/word_groups.dart' show showsTransliteration;
import '../../l10n/l10n.dart';
import '../../models/root.dart';
import '../../models/sentence.dart';
import '../../models/word.dart';

/// Offline-Wörterbuch (Task H2): sucht über `arabic`/`german`/
/// `transliteration` der 500 Wörter in SQLite. Einstieg über das Such-Icon in
/// der AppBar des Lernen-Tabs. Es werden **alle** verfügbaren Wörter
/// gefunden — die App ist komplett kostenlos, daher gibt es keine
/// Freischalt-/Kauf-Filterung mehr (die frühere Filterung auf
/// „freigeschaltete“ Sprachniveaus aus Task H2 entfiel, da alle 500 A1-Wörter
/// frei spielbar sind, 12. September 2026). Ein Treffer öffnet eine
/// Detailansicht mit Wurzel-Definition und Kontext-Sätzen.
class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _searchId = 0;
  List<Word> _found = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final id = ++_searchId;
    if (value.trim().isEmpty) {
      setState(() => _found = const []);
      return;
    }
    final found = await DatabaseHelper.instance.searchWords(value);
    if (!mounted || id != _searchId) {
      return;
    }
    setState(() => _found = found);
  }

  @override
  Widget build(BuildContext context) {
    final queryEmpty = _controller.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dictionaryTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.l10n.dictionaryHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _debounce?.cancel();
                            setState(() => _found = const []);
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildResults(context, queryEmpty)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, bool queryEmpty) {
    if (queryEmpty) {
      return _Hint(
        icon: Icons.menu_book,
        text: context.l10n.dictionaryEmptyHint,
      );
    }
    if (_found.isEmpty) {
      return _Hint(icon: Icons.search_off, text: context.l10n.noResults);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _found.length,
      itemBuilder: (context, index) {
        final word = _found[index];
        return _ResultTile(
          word: word,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _WordDetailScreen(word: word),
            ),
          ),
        );
      },
    );
  }
}
/// Zentrale Ergebniszeile im Wörterbuch — konsistente Karten-Optik (UI-1).
class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.word, required this.onTap});

  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Ink(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: AppTheme.cardDecoration(
              color: AppColors.surfaceElevated,
              borderColor: AppColors.border,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              word.arabic,
                              style: AppTheme.arabicTextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              word.german,
                              style: AppTheme.titleStyle(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${context.l10n.rootTitle(word.root)}'
                        '${word.transliteration.isNotEmpty ? ' · ${word.transliteration}' : ''}',
                        style: AppTheme.secondaryStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/// Detailansicht eines Suchtreffers: große Wort-Karte, Masdar (falls Verb),
/// klassische Wurzel-Definition und die drei Kontext-Sätze (Task H2).
class _WordDetailScreen extends ConsumerStatefulWidget {
  const _WordDetailScreen({required this.word});

  final Word word;

  @override
  ConsumerState<_WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<_WordDetailScreen> {
  WordRoot? _root;
  List<Sentence> _sentences = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final roots =
        await DatabaseHelper.instance.getRootsByKeys({widget.word.root});
    final sentences =
        await DatabaseHelper.instance.getSentencesByWordIds({widget.word.id});
    if (!mounted) {
      return;
    }
    setState(() {
      _root = roots[widget.word.root];
      _sentences = sentences[widget.word.id] ?? const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final showTransliteration = showsTransliteration(word.group);

    return Scaffold(
      appBar: AppBar(title: Text(word.german)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: AppTheme.cardDecoration(
                color: AppColors.surfaceElevated,
                borderColor: AppColors.border,
              ),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      word.arabic,
                      style: AppTheme.arabicTextStyle(fontSize: 44),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (showTransliteration && word.transliteration.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.transliteration,
                      style: AppTheme.secondaryStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      word.german,
                      style: AppTheme.bodyStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),

            if (word.masdar.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: context.l10n.masdarSection,
                accent: AppColors.gold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        word.masdar,
                        style: AppTheme.arabicTextStyle(
                          fontSize: 20,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    if (showTransliteration &&
                        word.masdarTransliteration.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        word.masdarTransliteration,
                        style: AppTheme.secondaryStyle(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (word.masdarGerman.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(word.masdarGerman, style: AppTheme.bodyStyle()),
                    ],
                  ],
                ),
              ),
            ],

            if (_root != null) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: context.l10n.rootTitle(_root!.root),
                child: Text(_root!.classicalDefinition, style: AppTheme.bodyStyle()),
              ),
            ],
if (_sentences.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: context.l10n.contextSentences,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _sentences.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildSentence(_sentences[i], showTransliteration),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSentence(Sentence sentence, bool showTransliteration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            sentence.arabic,
            style: AppTheme.arabicTextStyle(fontSize: 18),
          ),
        ),
        if (showTransliteration && sentence.transliteration.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sentence.transliteration,
            style: AppTheme.secondaryStyle(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 4),
        Text(sentence.german, style: AppTheme.bodyStyle(fontSize: 13)),
      ],
    );
  }
}
/// Gestapelte Inhalts-Box (Wurzel/Masdar/Sätze) in konsistenter Karten-Optik.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.accent = AppColors.primary,
  });

  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surface,
        borderColor: accent.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.titleStyle(fontSize: 14, color: accent)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Zentrale Leer-/Hinweis-Zustände (keine Eingabe, keine Treffer, gesperrt).
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTheme.secondaryStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}