import 'package:flutter/material.dart';

/// Карточка с фоном [baseColor], которая коротко «вспыхивает» цветом
/// [flashColor] каждый раз, когда меняется [trigger]. Удобно подсветить
/// игрока, который только что набрал очки.
///
/// Анимация не пересоздаёт [child] — внутреннее состояние дочерних виджетов
/// (например, счётчик-каунтап) сохраняется.
class FlashHighlight extends StatefulWidget {
  final int trigger;
  final Color baseColor;
  final Color flashColor;
  final double intensity;
  final BorderRadius borderRadius;
  final Widget child;

  const FlashHighlight({
    super.key,
    required this.trigger,
    required this.baseColor,
    required this.flashColor,
    required this.borderRadius,
    required this.child,
    this.intensity = 0.30,
  });

  @override
  State<FlashHighlight> createState() => _FlashHighlightState();
}

class _FlashHighlightState extends State<FlashHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(covariant FlashHighlight old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Сила вспышки: 1 в начале, плавно к 0; в покое — 0 (без подсветки).
        final f = _c.isAnimating ? (1 - Curves.easeOut.transform(_c.value)) : 0.0;
        final color = f <= 0
            ? widget.baseColor
            : (Color.lerp(widget.baseColor, widget.flashColor,
                    widget.intensity * f) ??
                widget.baseColor);
        return Material(
          color: color,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
