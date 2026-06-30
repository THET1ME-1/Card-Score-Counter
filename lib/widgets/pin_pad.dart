import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Крупная M3 PIN-панель: точки-индикатор + цифровая клавиатура. Когда введено
/// [length] цифр — зовёт [onCompleted] и очищается. [error] (меняющийся ключ)
/// запускает «тряску» и сброс.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int length;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onBiometric;
  final int errorTick;

  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.length = 4,
    this.onBiometric,
    this.errorTick = 0,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _entered = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.errorTick != old.errorTick) {
      setState(() => _entered = '');
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String d) {
    if (_entered.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _entered += d);
    if (_entered.length == widget.length) {
      final pin = _entered;
      // Небольшая задержка, чтобы успела закраситься последняя точка.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: scheme.onSurface,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 28),
        // Точки.
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final dx = _shake.isAnimating
                ? 12 *
                    (1 - _shake.value) *
                    math.sin(_shake.value * 3 * math.pi * 2)
                : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: i < _entered.length
                        ? scheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outline, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        // Клавиатура.
        for (final rowDigits in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final d in rowDigits) _key(scheme, d)],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _action(
                scheme,
                icon: widget.onBiometric != null ? Icons.fingerprint_rounded : null,
                onTap: widget.onBiometric,
              ),
              _key(scheme, '0'),
              _action(
                scheme,
                icon: Icons.backspace_rounded,
                onTap: _backspace,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(ColorScheme scheme, String d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _press(d),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(ColorScheme scheme, {IconData? icon, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: 72,
        height: 72,
        child: icon == null
            ? null
            : Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Center(
                    child: Icon(icon, size: 28, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
      ),
    );
  }
}
