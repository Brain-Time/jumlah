import 'dart:math';

import 'package:flutter/material.dart';

/// Karten-Flip-Übergang (Task E1, "Karten-Flip Animation (Vokabel-Karte)"):
/// dreht [child] einmal um die Y-Achse, sobald sich [itemKey] ändert (z.B.
/// beim Wortwechsel in `LearnScreen`) — die alte Karteninhalt dreht sich
/// weg, der neue dreht sich ein, statt abrupt zu wechseln.
class FlipCard extends StatefulWidget {
  const FlipCard({super.key, required this.itemKey, required this.child});

  final Object itemKey;
  final Widget child;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late Widget _previousChild = widget.child;

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemKey != oldWidget.itemKey) {
      _previousChild = oldWidget.child;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * pi;
        // Erste Haelfte: alte Karte dreht sich bis zur Kante weg (0 -> 90°).
        // Zweite Haelfte: neue Karte dreht sich von der Kante ein (90° -> 0).
        final showPrevious = angle < pi / 2;
        final displayAngle = showPrevious ? angle : angle - pi;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(displayAngle);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showPrevious ? _previousChild : widget.child,
        );
      },
    );
  }
}
