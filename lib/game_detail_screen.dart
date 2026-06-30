import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'models/game_session.dart';
import 'player_profile.dart';
import 'score_board_screen.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';
import 'widgets/player_shapes.dart';
import 'widgets/reveal.dart';
import 'widgets/share_result_sheet.dart';

/// Экран полной аналитики одной партии: сколько шла, кто сколько по времени
/// «держал ход», доли времени (кольцо), сравнение длительности с другими
/// партиями той же игры, итоговые места. Плоский Material 3 Expressive в духе
/// остального приложения — крупно, разнообразно.
class GameDetailScreen extends StatefulWidget {
  final GameSession game;
  final GameProfile? profile;
  final String title;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.profile,
    required this.title,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

/// Палитра для игроков без своего цвета (или для разнообразия колец).
const List<Color> _fallbackPalette = [
  Color(0xFF26C6DA),
  Color(0xFFFFB300),
  Color(0xFF7E57C2),
  Color(0xFFEF5350),
  Color(0xFF66BB6A),
  Color(0xFFFF7043),
];

class _GameDetailScreenState extends State<GameDetailScreen> {
  static const Color _gold = Color(0xFFFFD700);

  final GameRepository _repo = GameRepository.instance;

  final Map<String, PlayerProfile> _profilesByName = {};
  final Map<String, int> _shapeByName = {};

  /// Средняя длительность партий той же игры (мс), null — не с чем сравнивать.
  int? _avgDurationMs;
  int _sameTypeCount = 0;
  bool _loading = true;

  // Заметка к партии (функция, включается в настройках).
  bool _notesEnabled = false;
  String _note = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _repo.loadProfiles();
    for (var i = 0; i < profiles.length; i++) {
      _profilesByName[profiles[i].name] = profiles[i];
      _shapeByName[profiles[i].name] = i;
    }

    int? avg;
    var count = 0;
    final typeId = widget.profile?.id;
    if (typeId != null) {
      final games = await _repo.loadGames();
      final types = await _repo.gameTypes();
      final durations = <int>[];
      for (final g in games) {
        if (types[g.gameId] == typeId && g.durationMs > 0) {
          durations.add(g.durationMs);
          count++;
        }
      }
      if (durations.isNotEmpty) {
        avg = durations.reduce((a, b) => a + b) ~/ durations.length;
      }
    }

    final notesOn = await _repo.featureNotesEnabled();
    final note = (await _repo.gameNotes())[widget.game.gameId] ?? '';

    if (!mounted) return;
    setState(() {
      _avgDurationMs = avg;
      _sameTypeCount = count;
      _notesEnabled = notesOn;
      _note = note;
      _loading = false;
    });
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final scheme = Theme.of(context).colorScheme;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
            const SizedBox(height: 16),
            Text(
              tr('note'),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 280,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('note_hint')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(tr('save')),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _repo.setGameNote(widget.game.gameId, result);
    if (!mounted) return;
    setState(() => _note = result.trim());
  }

  Color _colorFor(String name, int index) =>
      _profilesByName[name]?.color ??
      _fallbackPalette[index % _fallbackPalette.length];

  int _shapeFor(String name) =>
      _shapeByName[name] ?? name.runes.fold(0, (a, b) => a + b);

  Widget _avatar(String name, int index, double radius) => ShapedAvatar(
        name: name,
        color: _colorFor(name, index),
        imagePath: _profilesByName[name]?.imagePath,
        size: radius * 2,
        shape: avatarShape(_shapeFor(name)),
      );

  /// Карточка заметки к партии: показывает текст или «Добавить заметку».
  Widget _noteCard(ColorScheme scheme) {
    final has = _note.isNotEmpty;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _editNote,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sticky_note_2_rounded,
                    size: 22, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('note'),
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      has ? _note : tr('add_note'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14,
                        height: 1.35,
                        fontStyle: has ? FontStyle.normal : FontStyle.italic,
                        color: has
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_rounded, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  /// Накопительный счёт каждого игрока по кругам (пропуски «—» переносят
  /// предыдущее значение). Для графика «гонка».
  List<List<double>> _raceSeries(int rounds) {
    final series = <List<double>>[];
    for (var i = 0; i < widget.game.players.length; i++) {
      final row = i < widget.game.scores.length
          ? widget.game.scores[i]
          : const <dynamic>[];
      final s = <double>[];
      var last = 0;
      for (var j = 0; j < rounds; j++) {
        final v = j < row.length ? row[j] : null;
        if (v is int) last = v;
        s.add(last.toDouble());
      }
      series.add(s);
    }
    return series;
  }

  Widget _raceChartCard(ColorScheme scheme) {
    final rounds = widget.game.scores.first.length;
    final series = _raceSeries(rounds);
    final colors = [
      for (var i = 0; i < widget.game.players.length; i++)
        _colorFor(widget.game.players[i], i)
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('race_chart'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _RaceChartPainter(series, colors, scheme),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (var i = 0; i < widget.game.players.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: colors[i], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.game.players[i],
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Итоговый счёт игрока — последнее число в его столбце очков.
  int _finalScore(int i) {
    if (i >= widget.game.scores.length) return 0;
    final row = widget.game.scores[i];
    for (var j = row.length - 1; j >= 0; j--) {
      if (row[j] is int) return row[j] as int;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = widget.game;
    final hasTiming = game.durationMs > 0;

    final cards = <Widget>[
      _headerCard(scheme),
      if (hasTiming) ...[
        _durationHero(scheme),
        if (_avgDurationMs != null) _comparisonCard(scheme),
        _timeByPlayerCard(scheme),
      ] else
        _noTimingCard(scheme),
      if ((game.scores.isNotEmpty ? game.scores.first.length : 0) >= 2)
        _raceChartCard(scheme),
      _standingsCard(scheme),
      if (_notesEnabled) _noteCard(scheme),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('game_analytics')),
        actions: [
          IconButton(
            tooltip: tr('share'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => ShareResultSheet.show(
              context,
              game: widget.game,
              gameTypeName: widget.profile?.displayName ?? widget.title,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              // Каскадное появление карточек (M3 emphasized): лёгкий подъём+fade.
              itemBuilder: (_, i) => Reveal(
                delay: Duration(milliseconds: 60 * i),
                child: cards[i],
              ),
            ),
      // У волейбола нет обычного табло — кнопку «продолжить/открыть» прячем.
      bottomNavigationBar: widget.profile?.winRule == WinRule.volleyball
          ? null
          : _resumeBar(scheme),
    );
  }

  // ------------------------------- Шапка -------------------------------

  Widget _headerCard(ColorScheme scheme) {
    final game = widget.game;
    final winner = game.winner;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.profile != null)
                _pill(Icons.style_rounded, widget.profile!.displayName,
                    scheme.primaryContainer, scheme.onPrimaryContainer),
              _pill(Icons.event_rounded, dateTimeShort(game.date),
                  scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
              _pill(
                  game.isFinished
                      ? Icons.emoji_events_rounded
                      : Icons.hourglass_top_rounded,
                  game.isFinished ? tr('finished_short') : tr('scoreboard'),
                  game.isFinished
                      ? _gold.withValues(alpha: 0.18)
                      : scheme.surfaceContainerHighest,
                  game.isFinished ? const Color(0xFFB8860B) : scheme.onSurfaceVariant),
            ],
          ),
          if (winner != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: scheme.onTertiaryContainer, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('winner'),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 12,
                            color: scheme.onTertiaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          winner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------- Длительность ---------------------------

  Widget _durationHero(ColorScheme scheme) {
    final game = widget.game;
    final rounds = game.rounds;
    final avgPerRound = rounds > 0
        ? Duration(milliseconds: game.durationMs ~/ rounds)
        : Duration.zero;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded,
                  size: 20, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                tr('game_duration'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Счётчик длительности «набегает» при появлении.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: game.durationMs.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                humanDuration(Duration(milliseconds: v.toInt())),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 52,
                  height: 1.0,
                  letterSpacing: -1.5,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat(scheme, '${game.rounds}', tr('rounds_played')),
              _miniDivider(scheme),
              _miniStat(scheme, clockDuration(avgPerRound), tr('avg_per_round')),
              _miniDivider(scheme),
              _miniStat(scheme, '${game.players.length}', tr('players_label')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(ColorScheme scheme, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 11.5,
              height: 1.15,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDivider(ColorScheme scheme) => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: scheme.onPrimaryContainer.withValues(alpha: 0.25),
      );

  // --------------------------- Сравнение ---------------------------

  Widget _comparisonCard(ColorScheme scheme) {
    final avg = _avgDurationMs!;
    final mine = widget.game.durationMs;
    final maxV = math.max(avg, mine).toDouble();
    final diff = avg == 0 ? 0.0 : (mine - avg) / avg * 100;
    final pct = diff.abs().round();

    String verdict;
    Color verdictColor;
    if (pct < 8) {
      verdict = tr('about_average');
      verdictColor = scheme.onSurfaceVariant;
    } else if (diff > 0) {
      verdict = trf('longer_by', {'p': pct});
      verdictColor = scheme.tertiary;
    } else {
      verdict = trf('shorter_by', {'p': pct});
      verdictColor = scheme.primary;
    }

    Widget bar(String label, int ms, Color color, bool emphasize) {
      final frac = maxV == 0 ? 0.0 : (ms / maxV).clamp(0.04, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      fontWeight:
                          emphasize ? FontWeight.w700 : FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  humanDuration(Duration(milliseconds: ms)),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: emphasize ? color : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 14, color: scheme.surfaceContainerHighest),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, w, __) => FractionallySizedBox(
                      widthFactor: w,
                      child: Container(height: 14, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('vs_average'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trf('vs_average_sub',
                {'game': widget.profile?.displayName ?? tr('scoreboard')}),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          bar(tr('this_game'), mine, scheme.primary, true),
          bar('${tr('avg_duration')} · $_sameTypeCount', avg,
              scheme.secondary, false),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: verdictColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              verdict,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: verdictColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------- Время по игрокам -------------------------

  Widget _timeByPlayerCard(ColorScheme scheme) {
    final game = widget.game;
    // Время по игрокам; дополняем нулями до числа игроков.
    final times = <int>[
      for (var i = 0; i < game.players.length; i++)
        i < game.playerTimesMs.length ? game.playerTimesMs[i] : 0,
    ];
    final total = times.fold<int>(0, (a, b) => a + b);

    if (total <= 0) {
      // Время по игрокам не записано (напр. Дурак/Президент/Phase 10).
      return _infoCard(scheme, tr('turn_time_by_player'),
          tr('no_time_data'), Icons.schedule_rounded);
    }

    // Сегменты кольца и индексы для подсветки быстрейшего/медленного.
    final colors = [
      for (var i = 0; i < game.players.length; i++)
        _colorFor(game.players[i], i)
    ];
    var fastest = 0, slowest = 0;
    for (var i = 1; i < times.length; i++) {
      if (times[i] < times[fastest]) fastest = i;
      if (times[i] > times[slowest]) slowest = i;
    }

    // Игроки по убыванию времени.
    final order = [for (var i = 0; i < game.players.length; i++) i]
      ..sort((a, b) => times[b].compareTo(times[a]));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('turn_time_by_player'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Кольцо долей времени + крупная подпись по центру.
          Center(
            child: SizedBox(
              width: 196,
              height: 196,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) => CustomPaint(
                  painter: _DonutPainter(
                    values: [for (final v in times) v.toDouble()],
                    colors: colors,
                    track: scheme.surfaceContainerHighest,
                    progress: t,
                  ),
                  child: child,
                ),
                // Ширину центра ограничиваем внутренним диаметром кольца, а
                // длительность вписываем в одну строку через FittedBox —
                // иначе «1 мин 26 сек» вылезает за пределы пончика.
                child: Center(
                  child: SizedBox(
                    width: 124,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            humanDuration(Duration(milliseconds: total)),
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('total_time_played'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (final i in order)
            _playerTimeRow(scheme, i, times[i], total, colors[i],
                isFastest: i == fastest && times.length > 1,
                isSlowest: i == slowest && times.length > 1 && slowest != fastest),
        ],
      ),
    );
  }

  Widget _playerTimeRow(
    ColorScheme scheme,
    int index,
    int ms,
    int total,
    Color color, {
    required bool isFastest,
    required bool isSlowest,
  }) {
    final name = widget.game.players[index];
    final pct = total == 0 ? 0 : (ms / total * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _avatar(name, index, 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Имя — на своей строке (не обрезается коротким именем);
                // ярлык «быстрее/дольше всех» уходит отдельной мелкой строкой.
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (isFastest || isSlowest) ...[
                  const SizedBox(height: 4),
                  isFastest
                      ? _tag(scheme, tr('fastest_player'), scheme.primary)
                      : _tag(scheme, tr('slowest_player'), scheme.tertiary),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                          height: 10, color: scheme.surfaceContainerHighest),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0,
                            end: total == 0
                                ? 0.0
                                : (ms / total).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, w, __) => FractionallySizedBox(
                          widthFactor: w,
                          child: Container(height: 10, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                humanDuration(Duration(milliseconds: ms)),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(ColorScheme scheme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ------------------------------- Итоги -------------------------------

  Widget _standingsCard(ColorScheme scheme) {
    final game = widget.game;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('rounds_history'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < game.players.length; i++)
            _standingRow(scheme, i),
        ],
      ),
    );
  }

  Widget _standingRow(ColorScheme scheme, int i) {
    final name = widget.game.players[i];
    final isWinner = widget.game.winner == name;
    final isOut = widget.game.eliminatedPlayers.contains(name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _avatar(name, i, 18),
          const SizedBox(width: 12),
          if (isWinner)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.emoji_events_rounded, size: 18, color: _gold),
            )
          else if (isOut)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.do_not_disturb_on_outlined,
                  size: 16, color: scheme.onSurfaceVariant),
            ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                color: isOut ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
          Text(
            '${_finalScore(i)}',
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: isWinner ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------- Прочее -------------------------------

  Widget _noTimingCard(ColorScheme scheme) => _infoCard(
        scheme,
        tr('no_time_data'),
        tr('no_time_data_hint'),
        Icons.schedule_rounded,
      );

  Widget _infoCard(
      ColorScheme scheme, String title, String body, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    height: 1.3,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumeBar(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              // Заменяем экран аналитики табло: после выхода из партии
              // пользователь попадает в Историю (она сама обновится), а не на
              // устаревшую аналитику.
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ScoreBoardScreen(
                    players: widget.game.players,
                    initialData: widget.game.toJson(),
                    profile: widget.profile,
                  ),
                ),
              );
            },
            icon: Icon(widget.game.isFinished
                ? Icons.visibility_rounded
                : Icons.play_arrow_rounded),
            label: Text(widget.game.isFinished
                ? tr('analytics_open')
                : tr('analytics_resume')),
          ),
        ),
      ),
    );
  }
}

/// Кольцо-«пончик» из сегментов по долям [values]. Сегменты разделены
/// небольшими зазорами; пустые значения пропускаются.
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;

  /// 0..1 — насколько развёрнуты сегменты (для анимации появления).
  final double progress;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.track,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final circle = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    const gap = 0.04; // зазор между сегментами (рад.)
    final p = progress.clamp(0.0, 1.0);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final sweep = 2 * math.pi * (v / total) * p;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colors[i % colors.length];
      final s = start + gap / 2;
      final e = math.max(0.0, sweep - gap);
      canvas.drawArc(circle, s, e, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values ||
      old.colors != colors ||
      old.track != track ||
      old.progress != progress;
}

/// График «гонка»: накопительный счёт каждого игрока по кругам (линии).
class _RaceChartPainter extends CustomPainter {
  final List<List<double>> series;
  final List<Color> colors;
  final ColorScheme scheme;
  _RaceChartPainter(this.series, this.colors, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.length < 2) return;
    final rounds = series.first.length;

    var minV = double.infinity, maxV = -double.infinity;
    for (final s in series) {
      for (final v in s) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    if (minV == maxV) {
      maxV += 1;
      minV -= 1;
    }
    const padL = 8.0, padR = 8.0, padT = 8.0, padB = 8.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    double xOf(int j) => padL + w * (j / (rounds - 1));
    double yOf(double v) => padT + h * (1 - (v - minV) / (maxV - minV));

    // Базовые горизонтальные линии.
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = padT + h * k / 3;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), grid);
    }

    for (var i = 0; i < series.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var j = 0; j < rounds; j++) {
        final p = Offset(xOf(j), yOf(series[i][j]));
        if (j == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
      // Точка в конце линии.
      canvas.drawCircle(
        Offset(xOf(rounds - 1), yOf(series[i][rounds - 1])),
        4,
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(_RaceChartPainter old) =>
      old.series != series || old.colors != colors;
}
