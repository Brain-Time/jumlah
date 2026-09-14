import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/sentence.dart';

/// Wort-für-Wort-Analyse eines Kontext-Satzes: aufklappbar (via [expanded]),
/// einzelne Wörter sind tippbar und zeigen dann ihre Übersetzung.
class AnalysisWidget extends StatefulWidget {
  const AnalysisWidget({
    super.key,
    required this.sentence,
    required this.expanded,
  });

  final Sentence sentence;
  final bool expanded;

  @override
  State<AnalysisWidget> createState() => _AnalysisWidgetState();
}

class _AnalysisWidgetState extends State<AnalysisWidget> {
  int? _highlightedIndex;

  @override
  void didUpdateWidget(covariant AnalysisWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence != widget.sentence) {
      _highlightedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: widget.expanded
          ? _buildAnalysis(context)
          : const SizedBox(width: double.infinity, height: 0),
    );
  }

  Widget _buildAnalysis(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.sentence.wordAnalysis.length; i++)
              _buildWordChip(i),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(int index) {
    final entry = widget.sentence.wordAnalysis[index];
    final isHighlighted = _highlightedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _highlightedIndex = isHighlighted ? null : index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.gold.withValues(alpha: 0.25)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHighlighted ? AppColors.gold : Colors.white24,
              ),
            ),
            child: Text(
              entry.word,
              style: AppTheme.arabicTextStyle(fontSize: 20),
            ),
          ),
          if (isHighlighted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.translation,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
