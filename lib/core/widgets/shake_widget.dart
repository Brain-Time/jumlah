import 'dart:math';

import 'package:flutter/material.dart';

/// Horizontales Wackeln als Fehler-Feedback (Task E1). Jede Änderung von
/// [trigger] (z.B. ein Versuchszähler) löst eine neue Wackel-Animation aus —
/// unabhängig davon, ob sich [child] selbst ändert.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.trigger, required this.child});

  final Object trigger;
  final Widget child;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
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
      builder: (context, child) {
        // Abklingende Sinus-Schwingung: schnelles Wackeln, das gegen Ende
        // der Dauer ausklingt statt abrupt zu stoppen.
        final decay = 1 - _controller.value;
        final offset = sin(_controller.value * pi * 6) * 8 * decay;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}
