import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Анимация броска кубика прямо на месте счёта игрока: число быстро «крутится»
/// случайными значениями и тормозит на итоговом. Чисто на удачу — счёт не
/// меняет. Крит (максимум) подсвечивается золотым, провал (1) — приглушённым.
class DiceRoll extends StatefulWidget {
  final int sides;
  final Color color;
  final TextStyle numberStyle;

  /// Вызывается, когда кубик «упал» (для вибро/звука на стороне экрана).
  final ValueChanged<int>? onSettled;

  const DiceRoll({
    super.key,
    required this.sides,
    required this.color,
    required this.numberStyle,
    this.onSettled,
  });

  @override
  State<DiceRoll> createState() => _DiceRollState();
}

class _DiceRollState extends State<DiceRoll> {
  final Random _rng = Random();
  int _display = 1;
  int? _final;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _display = 1 + _rng.nextInt(widget.sides);
    _schedule(60);
  }

  void _schedule(int ms) {
    Future.delayed(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _tick++;
      // Замедляемся к концу — крутим ~18 кадров с растущим интервалом.
      if (_tick < 18 && ms < 190) {
        setState(() => _display = 1 + _rng.nextInt(widget.sides));
        _schedule(ms + 12);
      } else {
        final f = 1 + _rng.nextInt(widget.sides);
        setState(() {
          _display = f;
          _final = f;
        });
        HapticFeedback.mediumImpact();
        widget.onSettled?.call(f);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final landed = _final != null;
    final isCrit = landed && _final == widget.sides;
    final isFail = landed && _final == 1;
    final numberColor = isCrit
        ? const Color(0xFFFFD700)
        : isFail
            ? widget.color.withValues(alpha: 0.55)
            : widget.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Метка типа кубика.
        Text(
          'd${widget.sides}',
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
            color: widget.color.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        // Крупное число с «подскоком» при приземлении.
        TweenAnimationBuilder<double>(
          key: ValueKey(landed),
          tween: Tween(begin: landed ? 0.6 : 1.0, end: 1.0),
          duration: Duration(milliseconds: landed ? 280 : 0),
          curve: AppTheme.emphasized,
          builder: (context, s, child) =>
              Transform.scale(scale: s, child: child),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$_display',
              style: widget.numberStyle.copyWith(color: numberColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Набор кубиков для выбора (как в настолках).
const List<int> kDiceSides = [4, 6, 8, 10, 12, 20];
