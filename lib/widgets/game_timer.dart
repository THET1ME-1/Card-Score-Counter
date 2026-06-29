import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Опциональный таймер партии и текущего хода для табло.
///
/// «Партия» считает общее время; «Ход» сбрасывается каждый раз, когда меняется
/// [turnTick] (передаётся табло при передаче хода) — удобно для блица/Дурака.
class GameTimer extends StatefulWidget {
  final int turnTick;
  const GameTimer({super.key, required this.turnTick});

  @override
  State<GameTimer> createState() => _GameTimerState();
}

class _GameTimerState extends State<GameTimer> {
  final Stopwatch _game = Stopwatch();
  final Stopwatch _turn = Stopwatch();
  Timer? _ticker;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _game.start();
    _turn.start();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant GameTimer old) {
    super.didUpdateWidget(old);
    // Передан ход — обнуляем таймер хода (общий таймер продолжает идти).
    if (widget.turnTick != old.turnTick) {
      _turn
        ..reset()
        ..stop();
      if (_running) _turn.start();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_running) {
        _game.stop();
        _turn.stop();
        _ticker?.cancel();
      } else {
        _game.start();
        _turn.start();
        _startTicker();
      }
      _running = !_running;
    });
  }

  void _reset() {
    setState(() {
      _game.reset();
      _turn.reset();
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _slot(scheme, tr('timer_match'), _fmt(_game.elapsed), true),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: scheme.outlineVariant,
          ),
          _slot(scheme, tr('timer_turn'), _fmt(_turn.elapsed), false),
          const Spacer(),
          IconButton(
            tooltip: _running ? tr('pause') : tr('resume'),
            onPressed: _toggle,
            icon: Icon(_running
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: tr('reset'),
            onPressed: _reset,
            icon: const Icon(Icons.replay_rounded),
          ),
        ],
      ),
    );
  }

  Widget _slot(ColorScheme scheme, String label, String value, bool primary) {
    return Semantics(
      label: '$label $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: primary ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
