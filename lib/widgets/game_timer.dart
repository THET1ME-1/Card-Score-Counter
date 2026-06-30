import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Панель таймера партии/хода для табло — чисто отображение.
///
/// Само время считает и хранит экран табло (чтобы длительность партии
/// сохранялась в историю независимо от того, показана панель или нет). Виджет
/// получает готовые значения и колбэки паузы/сброса и перерисовывается, когда
/// табло обновляет состояние раз в секунду.
class GameTimer extends StatelessWidget {
  final Duration matchElapsed;
  final Duration turnElapsed;
  final bool running;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  const GameTimer({
    super.key,
    required this.matchElapsed,
    required this.turnElapsed,
    required this.running,
    required this.onToggle,
    required this.onReset,
  });

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
          _slot(scheme, tr('timer_match'), clockDuration(matchElapsed), true),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: scheme.outlineVariant,
          ),
          _slot(scheme, tr('timer_turn'), clockDuration(turnElapsed), false),
          const Spacer(),
          IconButton(
            tooltip: running ? tr('pause') : tr('resume_timer'),
            onPressed: onToggle,
            icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: tr('reset'),
            onPressed: onReset,
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
