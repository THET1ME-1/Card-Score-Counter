import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/strings.dart';
import 'models/volleyball_match.dart';
import 'services/game_repository.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';
import 'widgets/count_up_number.dart';
import 'widgets/pressable.dart';

/// Умное табло для волейбола: две команды, крупный счёт, тап по половине — очко.
/// Сеты/серв/таймлайн, три формата матча, портрет и ландшафт. Выбор игроков не
/// нужен — это отдельный быстрый экран счёта.
class VolleyballScreen extends StatefulWidget {
  const VolleyballScreen({super.key});

  @override
  State<VolleyballScreen> createState() => _VolleyballScreenState();
}

class _VolleyballScreenState extends State<VolleyballScreen> {
  final GameRepository _repo = GameRepository.instance;

  late VolleyballMatch _match;
  bool _swapped = false; // визуальная смена сторон (данные не трогаем)
  bool _savedToHistory = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Волейболу удобно и в ландшафте — разрешаем обе ориентации.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  Future<void> _load() async {
    final active = await _repo.loadActiveVolleyball();
    if (!mounted) return;
    setState(() {
      _match = active ?? _newMatch();
      _savedToHistory = false;
      _ready = true;
    });
  }

  VolleyballMatch _newMatch() => VolleyballMatch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        teamNames: [tr('vb_home'), tr('vb_guest')],
        teamColors: const [0xFF3FA34D, 0xFF3B6FE0],
        config: const VolleyballConfig(),
      );

  @override
  void dispose() {
    // Возвращаем приложение в портрет.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _persist() => _repo.saveActiveVolleyball(_match);

  // ------------------------------ Действия ------------------------------

  void _addPoint(int team) {
    final wasFinished = _match.replay().finished;
    if (wasFinished) return;
    HapticFeedback.lightImpact();
    SoundService.instance.play(Sfx.point);
    setState(() => _match.events.add(team));
    _persist();
    final st = _match.replay();
    if (st.finished && !_savedToHistory) {
      _savedToHistory = true;
      SoundService.instance.play(Sfx.win);
      _repo.saveVolleyballToHistory(_match, st);
      _repo.clearActiveVolleyball();
    }
  }

  void _undo() {
    if (_match.events.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _match.events.removeLast();
      // Откатили возможный финал — снова считаем матч активным.
      if (!_match.replay().finished) _savedToHistory = false;
    });
    _persist();
  }

  void _endSetFree() {
    final st = _match.replay();
    if (st.pointsA == 0 && st.pointsB == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _match.events.add(-1));
    _persist();
  }

  void _finishFree() {
    final st = _match.replay();
    // Засчитываем текущий незакрытый сет, если в нём есть очки.
    if (st.pointsA > 0 || st.pointsB > 0) {
      _match.events.add(-1);
    }
    final fin = _match.replay();
    final winner = fin.setsA > fin.setsB
        ? 0
        : fin.setsB > fin.setsA
            ? 1
            : null;
    if (fin.completedSets.isNotEmpty) {
      // Победитель — у кого больше сетов (или null при ничьей).
      final finished = VbState(
        pointsA: fin.pointsA,
        pointsB: fin.pointsB,
        setsA: fin.setsA,
        setsB: fin.setsB,
        server: fin.server,
        finished: true,
        winner: winner,
        completedSets: fin.completedSets,
        setTimelines: fin.setTimelines,
      );
      _repo.saveVolleyballToHistory(_match, finished);
    }
    _newMatchReset();
  }

  void _newMatchReset() {
    setState(() {
      _match = _newMatch();
      _savedToHistory = false;
      _swapped = false;
    });
    _repo.clearActiveVolleyball();
    _persist();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('vb_reset_q')),
        content: Text(tr('vb_reset_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('vb_new_match'))),
        ],
      ),
    );
    if (ok == true) _newMatchReset();
  }

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() => _swapped = !_swapped);
  }

  // ------------------------------ Конфиг ------------------------------

  Future<void> _openConfig() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = _match.config;
          void apply(VolleyballConfig nc) {
            setState(() => _match.config = nc);
            setSheet(() {});
            _persist();
          }

          Widget formatTile(VbFormat f, String label) {
            final sel = c.format == f;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: sel ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => apply(c.copyWith(format: f)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          sel
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: sel ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          Widget stepper(String label, int value, VoidCallback dec,
              VoidCallback inc) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                      onPressed: dec,
                      icon: const Icon(Icons.remove_rounded)),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                      onPressed: inc, icon: const Icon(Icons.add_rounded)),
                ],
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr('vb_config'),
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  formatTile(VbFormat.standard, tr('vb_format_standard')),
                  formatTile(VbFormat.short, tr('vb_format_short')),
                  formatTile(VbFormat.free, tr('vb_format_free')),
                  if (!c.isFree) ...[
                    const SizedBox(height: 6),
                    stepper(
                      tr('vb_points'),
                      c.pointsToWin,
                      () => apply(c.copyWith(
                          pointsToWin: (c.pointsToWin - 1).clamp(5, 99))),
                      () => apply(c.copyWith(
                          pointsToWin: (c.pointsToWin + 1).clamp(5, 99))),
                    ),
                    stepper(
                      tr('vb_tiebreak'),
                      c.tiebreakPoints,
                      () => apply(c.copyWith(
                          tiebreakPoints: (c.tiebreakPoints - 1).clamp(5, 99))),
                      () => apply(c.copyWith(
                          tiebreakPoints: (c.tiebreakPoints + 1).clamp(5, 99))),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('done')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------- UI -------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final st = _match.replay();
    final c = _match.config;

    // Индексы команд слева/справа с учётом визуальной смены сторон.
    final li = _swapped ? 1 : 0;
    final ri = _swapped ? 0 : 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('game_volleyball')),
        actions: [
          IconButton(
            tooltip: tr('undo'),
            onPressed: _match.events.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: tr('vb_swap'),
            onPressed: _swap,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: tr('vb_config'),
            onPressed: _openConfig,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: tr('vb_new_match'),
            onPressed: _confirmReset,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Шапка: сеты + серв.
            _setsHeader(st, li, ri, scheme),
            // Два больших табло.
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: _teamTile(st, li, scheme)),
                    const SizedBox(width: 12),
                    Expanded(child: _teamTile(st, ri, scheme)),
                  ],
                ),
              ),
            ),
            // Свободный режим: завершить сет/матч.
            if (c.isFree && !st.finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: PressableScale(
                        child: FilledButton.tonalIcon(
                          onPressed: _endSetFree,
                          icon: const Icon(Icons.flag_rounded),
                          label: Text(tr('vb_end_set')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PressableScale(
                        child: FilledButton.icon(
                          onPressed: _finishFree,
                          icon: const Icon(Icons.emoji_events_rounded),
                          label: Text(tr('vb_finish_match')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Победный баннер.
            if (st.finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _winnerBanner(st, scheme),
              ),
            // Таймлайн.
            Expanded(
              flex: 3,
              child: _timeline(st, scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setsHeader(VbState st, int li, int ri, ColorScheme scheme) {
    Color col(int i) => Color(_match.teamColors[i]);
    Widget side(int i, bool left) {
      final serving = st.server == i && !st.finished;
      final name = _match.teamNames[i];
      return Expanded(
        child: Row(
          mainAxisAlignment:
              left ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (!left && serving) ...[
              Icon(Icons.sports_volleyball_rounded, size: 18, color: col(i)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: col(i),
                ),
              ),
            ),
            if (left && serving) ...[
              const SizedBox(width: 6),
              Icon(Icons.sports_volleyball_rounded, size: 18, color: col(i)),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          side(li, true),
          // Счёт по сетам по центру.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_setsOf(st, li)}',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: col(li),
                  ),
                ),
                Text(
                  ' : ',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${_setsOf(st, ri)}',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: col(ri),
                  ),
                ),
              ],
            ),
          ),
          side(ri, false),
        ],
      ),
    );
  }

  int _setsOf(VbState st, int i) => i == 0 ? st.setsA : st.setsB;
  int _pointsOf(VbState st, int i) => i == 0 ? st.pointsA : st.pointsB;

  Widget _teamTile(VbState st, int i, ColorScheme scheme) {
    final color = Color(_match.teamColors[i]);
    final pts = _pointsOf(st, i);
    final disabled = st.finished;
    // Подсказка сет/матчбол.
    final hint = _pointHint(st, i);

    return PressableScale(
      pressedScale: 0.98,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : () => _addPoint(i),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (hint != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CountUpNumber(
                        value: pts,
                        style: const TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 180,
                          height: 1.0,
                          letterSpacing: -4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  _match.teamNames[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// «Сетбол»/«Матчбол» для команды [i], если на следующем очке закрывается
  /// сет (и, возможно, матч).
  String? _pointHint(VbState st, int i) {
    final c = _match.config;
    if (c.isFree || st.finished) return null;
    final isDecider = st.setsA == c.setsToWin - 1 && st.setsB == c.setsToWin - 1;
    final target = isDecider ? c.tiebreakPoints : c.pointsToWin;
    final mine = _pointsOf(st, i);
    final other = _pointsOf(st, i == 0 ? 1 : 0);
    if (mine + 1 >= target && (mine + 1) - other >= c.winBy) {
      final willWinMatch = _setsOf(st, i) + 1 >= c.setsToWin;
      return willWinMatch ? tr('vb_match_point') : tr('vb_set_point');
    }
    return null;
  }

  Widget _winnerBanner(VbState st, ColorScheme scheme) {
    final w = st.winner!;
    final color = Color(_match.teamColors[w]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${tr('winner')}: ${_match.teamNames[w]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
          ),
          PressableScale(
            child: FilledButton.icon(
              onPressed: _newMatchReset,
              icon: const Icon(Icons.replay_rounded),
              label: Text(tr('vb_new_match')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(VbState st, ColorScheme scheme) {
    final colA = Color(_match.teamColors[0]);
    final colB = Color(_match.teamColors[1]);
    // Все сеты: завершённые + текущий (если есть очки).
    final total = st.setTimelines.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('vb_timeline'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: total,
              itemBuilder: (context, setIdx) {
                final pts = st.setTimelines[setIdx];
                if (pts.isEmpty && setIdx == total - 1 && total > 1) {
                  return const SizedBox.shrink();
                }
                final isCurrent = setIdx >= st.completedSets.length;
                final finalA = setIdx < st.completedSets.length
                    ? st.completedSets[setIdx][0]
                    : st.pointsA;
                final finalB = setIdx < st.completedSets.length
                    ? st.completedSets[setIdx][1]
                    : st.pointsB;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isCurrent
                                ? tr('vb_current_set')
                                : trf('vb_set_n', {'n': setIdx + 1}),
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$finalA : $finalB',
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Две строки чипов: очки команды A и B по мере набора.
                      _timelineRow(pts, 0, colA),
                      const SizedBox(height: 3),
                      _timelineRow(pts, 1, colB),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(List<VbPoint> pts, int team, Color color) {
    final mine = [for (final p in pts) if (p.team == team) p.score];
    return SizedBox(
      height: 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: mine.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => Container(
          width: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${mine[i]}',
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
