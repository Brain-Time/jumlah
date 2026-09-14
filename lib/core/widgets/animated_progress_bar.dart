import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fortschrittsbalken (Task E1), der Wertänderungen weich animiert statt
/// abrupt zu springen — ersetzt das direkte `LinearProgressIndicator` an
/// allen Stellen, wo sich `value` über die Zeit ändert (Lern-/Quiz-
/// Fortschritt, Gruppen-Fortschritt).
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.gold,
    this.minHeight = 6,
  });

  final double value;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            value: animatedValue,
            backgroundColor: Colors.white12,
            color: color,
            minHeight: minHeight,
          );
        },
      ),
    );
  }
}
