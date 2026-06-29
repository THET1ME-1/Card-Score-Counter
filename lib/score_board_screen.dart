import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'add_scores_screen.dart';
import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'models/game_session.dart';
import 'services/game_repository.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';

class ScoreBoardScreen extends StatefulWidget {
  final List<String> players;
  final Map<String, dynamic>? initialData;

  /// Профиль игры (правила подсчёта). Если null — поведение «101» (на вылет).
  final GameProfile? profile;

  const ScoreBoardScreen({
    super.key,
    required this.players,
    this.initialData,
    this.profile,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ScoreBoardScreenState createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  final GameRepository _repo = GameRepository.instance;

  /// Граница для рендера табло в картинку при «Поделиться».
  final GlobalKey _boardKey = GlobalKey();

  List<List<dynamic>> scores = [];
  List<String> remainingPlayers = [];
  List<String> eliminatedPlayers = [];
  int rounds = 0;
  List<int> dividerIndices = [];
  double _textSize = 16.0;
  int currentPlayerIndex = 0;
  String? gameId;

  /// Победа за эту партию уже начислена в счётчик профиля.
  /// Флаг защищает от двойного начисления при повторном завершении/отмене.
  bool winCredited = false;

  /// Имя игрока, которому начислена победа за эту партию (или null).
  /// Нужен, чтобы при правках/отмене корректно снять/переначислить победу.
  String? _creditedTo;

  /// Правила игры (из профиля). По умолчанию — «101» на вылет до 101.
  late int _target;
  late WinRule _rule;

  /// Текущий вычисленный победитель и завершённость по правилу.
  bool _finished = false;
  String? _winner;

  /// Победитель, выбранный вручную (для правила [WinRule.manual] — Дурак,
  /// Бридж, Президент и т.п., где победителя нельзя вычислить по очкам).
  String? _manualWinner;

  /// Звуки взводятся только после первичной инициализации, чтобы при открытии
  /// уже завершённой партии не проигрывался фанфар победы.
  bool _sfxArmed = false;

  /// Сработал ли в последнем пересчёте «терминальный» звук (победа/вылет) —
  /// чтобы поверх него не накладывать звук обычного очка.
  bool _sfxFired = false;

  @override
  void initState() {
    super.initState();
    _loadTextSize();
    _rule = widget.profile?.winRule ?? WinRule.elimination;
    _target = widget.profile?.target ?? 101;
    if (widget.initialData != null) {
      final data = widget.initialData!;
      scores = List<List<dynamic>>.from(data['scores'] ?? []);
      remainingPlayers = List<String>.from(data['remainingPlayers'] ?? []);
      eliminatedPlayers = List<String>.from(data['eliminatedPlayers'] ?? []);
      rounds = data['rounds'] ?? 0;
      dividerIndices = List<int>.from(data['dividerIndices'] ?? []);
      currentPlayerIndex = data['currentPlayerIndex'] ?? 0;
      gameId = data['gameId']?.toString();
      winCredited = data['winCredited'] as bool? ?? false;
      _manualWinner = data['winnerName']?.toString();
    } else {
      scores = List.generate(widget.players.length, (_) => []);
      remainingPlayers = List.from(widget.players);
      gameId = DateTime.now().millisecondsSinceEpoch.toString();
      // Помечаем партию выбранной игрой (для истории).
      if (widget.profile != null) {
        _repo.setGameType(gameId!, widget.profile!.id);
      }
    }
    // Кто уже получил победу за эту партию (для сверки начислений).
    _creditedTo = winCredited ? _winnerByRule() : null;
    // Пересчитываем статусы под актуальное правило игры. Это само-исцеляет
    // партии, сохранённые под другим правилом (напр. Дурак, который из-за
    // прежнего бага считался «на вылет до 101»): выбывшие сбрасываются, если
    // правило не на вылет, а победитель/итоги приводятся к правилу.
    _recomputeStatuses();
    // С этого момента переходы состояния озвучиваются.
    _sfxArmed = true;
  }

  Future<void> _loadTextSize() async {
    final size = await _repo.textSize();
    if (!mounted) return;
    setState(() => _textSize = size);
  }

  /// Текущее состояние партии как модель.
  GameSession _session() => GameSession(
        gameId: gameId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        players: widget.players,
        scores: scores,
        rounds: rounds,
        remainingPlayers: remainingPlayers,
        eliminatedPlayers: eliminatedPlayers,
        dividerIndices: dividerIndices,
        currentPlayerIndex: currentPlayerIndex,
        date: DateTime.now(),
        winCredited: winCredited,
        // Явно сохраняем победителя — иначе игры не на вылет (гонка/минимум/
        // ручной режим) не знали бы победителя в истории и статистике.
        winnerName: _winner,
      );

  /// Сохраняет партию в историю. Пустые партии (без единого очка) не пишутся —
  /// это заодно избавляет от прежнего костыля с удалением «пустых игр».
  Future<void> _persist() async {
    if (scores.every((row) => row.isEmpty)) return;
    await _repo.upsertGame(_session());
  }

  void addScores(List<int> roundScores) {
    setState(() {
      int remainingIndex = 0;

      for (int i = 0; i < widget.players.length; i++) {
        if (eliminatedPlayers.contains(widget.players[i])) {
          scores[i].add('—');
          continue;
        }

        if (roundScores[remainingIndex] == 0) {
          scores[i].add('—');
        } else {
          int lastValidScore = 0;
          for (int j = scores[i].length - 1; j >= 0; j--) {
            if (scores[i][j] is int) {
              lastValidScore = scores[i][j];
              break;
            }
          }
          scores[i].add(lastValidScore + roundScores[remainingIndex]);
        }
        remainingIndex++;
      }

      // Вылеты/победитель — по правилу игры.
      _recomputeStatuses();
      // Обычный записанный круг (без победы/вылета) — мягкий звук очка.
      if (!_sfxFired) SoundService.instance.play(Sfx.point);

      // Раунд засчитываем, только если партия не завершилась этим ходом.
      if (!_finished) {
        rounds++;
        final live = remainingPlayers.isEmpty
            ? widget.players.length
            : remainingPlayers.length;
        if (live > 0 && rounds % live == 0) {
          dividerIndices.add(scores[0].length);
        }
      }

      _persist();
      _advanceToNextPlayer();
    });
  }

  void _advanceToNextPlayer() {
    setState(() {
      do {
        currentPlayerIndex = (currentPlayerIndex + 1) % widget.players.length;
      } while (eliminatedPlayers.contains(widget.players[currentPlayerIndex]));
    });
    _persist();
  }

  /// Можно ли отменить последний ход — пока записан хотя бы один.
  /// Важно: финальный (победный) ход тоже считается, хотя счётчик [rounds]
  /// на нём не увеличивается. Иначе победу нельзя было бы отменить.
  bool get canUndo => scores.isNotEmpty && scores.first.isNotEmpty;

  void undoLastRound() {
    if (!canUndo) return;
    setState(() {
      final wasFinished = _finished;

      // Убираем последний столбец очков у всех.
      for (int i = 0; i < widget.players.length; i++) {
        if (scores[i].isNotEmpty) scores[i].removeLast();
      }

      // На победном ходу rounds не рос — уменьшаем только если ход был обычный.
      if (!wasFinished && rounds > 0) rounds--;

      // Убираем разделители, оказавшиеся за пределами оставшихся столбцов.
      final cols = scores.isEmpty ? 0 : scores.first.length;
      dividerIndices.removeWhere((d) => d > cols);

      _recomputeStatuses();
      _persist();
      _advanceToPreviousPlayer();
    });
  }

  /// Пересобирает вылеты/оставшихся и победителя СТРОГО по очкам и правилу
  /// игры. Используется при ходе, отмене и ручной правке.
  void _recomputeStatuses() {
    final wasFinished = _finished;
    final prevEliminated = eliminatedPlayers.toSet();
    _sfxFired = false;
    remainingPlayers = [];
    eliminatedPlayers = [];
    for (int i = 0; i < widget.players.length; i++) {
      // Вылет — только в режиме «на вылет» (101 и т.п.).
      final out = _rule == WinRule.elimination &&
          scores[i].isNotEmpty &&
          _currentTotal(i) >= _target;
      if (out) {
        eliminatedPlayers.add(widget.players[i]);
      } else {
        remainingPlayers.add(widget.players[i]);
      }
    }
    // Если вдруг выбыли все — возвращаем всех в игру (страховка).
    if (remainingPlayers.isEmpty && widget.players.isNotEmpty) {
      remainingPlayers = List.from(widget.players);
      eliminatedPlayers.clear();
    }

    _winner = _winnerByRule();
    _finished = _winner != null;

    // Сверяем, кому сейчас положена победа, с тем, кому она начислена.
    if (_winner != _creditedTo) {
      if (_creditedTo != null) _repo.adjustWins(_creditedTo!, -1);
      if (_winner != null) _repo.adjustWins(_winner!, 1);
      _creditedTo = _winner;
      winCredited = _winner != null;
    }

    // Звуки по переходам состояния (после инициализации).
    if (_sfxArmed) {
      if (_finished && !wasFinished) {
        SoundService.instance.play(Sfx.win);
        _sfxFired = true;
      } else if (!_finished &&
          eliminatedPlayers.toSet().difference(prevEliminated).isNotEmpty) {
        SoundService.instance.play(Sfx.eliminate);
        _sfxFired = true;
      }
    }
  }

  /// Победитель по текущим очкам и правилу (или null, если игра не окончена).
  String? _winnerByRule() {
    switch (_rule) {
      case WinRule.elimination:
        return remainingPlayers.length == 1 ? remainingPlayers.first : null;
      case WinRule.raceHigh:
        // Кто первым дошёл до порога — берём наибольший итог >= порога.
        String? best;
        int bestTotal = -1;
        for (int i = 0; i < widget.players.length; i++) {
          final t = _currentTotal(i);
          if (scores[i].isNotEmpty && t >= _target && t > bestTotal) {
            best = widget.players[i];
            bestTotal = t;
          }
        }
        return best;
      case WinRule.lowestAtCap:
        // Дошли до порога — конец, побеждает наименьший итог.
        final reached = List.generate(widget.players.length,
                (i) => scores[i].isNotEmpty && _currentTotal(i) >= _target)
            .any((x) => x);
        if (!reached) return null;
        String? low;
        int lowTotal = 1 << 30;
        for (int i = 0; i < widget.players.length; i++) {
          final t = _currentTotal(i);
          if (t < lowTotal) {
            low = widget.players[i];
            lowTotal = t;
          }
        }
        return low;
      case WinRule.manual:
      case WinRule.fool:
      case WinRule.ranking:
        // Победителя в ручном режиме, «Дураке» и «Президенте» фиксирует
        // пользователь (кнопка «Завершить»).
        return _manualWinner;
      case WinRule.phases:
        // Победитель — кто первым прошёл фазу 10 (фаза стала 11).
        for (int i = 0; i < widget.players.length; i++) {
          if (_phaseOf(i) >= 11) return widget.players[i];
        }
        return null;
    }
  }

  /// Текущая фаза игрока в режиме [WinRule.phases] (минимум 1; 11 = прошёл всё).
  int _phaseOf(int i) {
    final v = _currentTotal(i);
    return v < 1 ? 1 : v;
  }

  /// Фаза для показа (1..10; «11» прячем — это «готово»).
  int _phaseDisplay(int i) {
    final p = _phaseOf(i);
    return p > 10 ? 10 : p;
  }

  /// Добавить кон в Phase 10: отмеченные прошли свою фазу (+1), остальные — нет.
  void _addPhasesRound(Set<int> passed) {
    setState(() {
      for (int i = 0; i < widget.players.length; i++) {
        int p = _phaseOf(i);
        if (passed.contains(i) && p < 11) p += 1;
        scores[i].add(p);
      }
      rounds++;
      _recomputeStatuses();
      if (!_finished) {
        final live = remainingPlayers.isEmpty
            ? widget.players.length
            : remainingPlayers.length;
        if (live > 0 && rounds % live == 0) {
          dividerIndices.add(scores[0].length);
        }
      }
      _persist();
    });
  }

  /// Нижняя панель «Кто прошёл фазу?» — чекбоксы по игрокам.
  Future<void> _pickPhasePassers() async {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.players.length;
    final passed = <int>{};
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('who_passed_phase'),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < n; i++)
                  Builder(builder: (_) {
                    final on = passed.contains(i);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: on
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setSheet(() {
                            if (on) {
                              passed.remove(i);
                            } else {
                              passed.add(i);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  on
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: on
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    widget.players[i],
                                    style: TextStyle(
                                      fontFamily: AppTheme.bodyFont,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: on
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  trf('phase_n', {'n': _phaseDisplay(i)}),
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFont,
                                    fontSize: 13,
                                    color: on
                                        ? scheme.onPrimaryContainer
                                            .withValues(alpha: 0.8)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, Set<int>.of(passed)),
                    child: Text(tr('done')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) _addPhasesRound(result);
  }

  /// Текущий титул игрока в «Президенте» по месту в общем зачёте (очки убыв.).
  String _rankTitle(int index) {
    final n = widget.players.length;
    final order = [for (int i = 0; i < n; i++) i]
      ..sort((a, b) {
        final d = _currentTotal(b).compareTo(_currentTotal(a));
        return d != 0 ? d : a.compareTo(b);
      });
    final p = order.indexOf(index);
    if (p == 0) return tr('title_president');
    if (p == n - 1) return tr('title_bum');
    if (n >= 4 && p == 1) return tr('title_vice_president');
    if (n >= 4 && p == n - 2) return tr('title_vice_bum');
    return tr('title_citizen');
  }

  /// Добавить кон в «Президенте»: за место даются очки (1-й — больше всех).
  void _addRankingRound(List<int> order) {
    setState(() {
      final n = widget.players.length;
      for (int pos = 0; pos < order.length; pos++) {
        final i = order[pos];
        final gain = n - 1 - pos; // 1-е место → n-1, последнее → 0
        scores[i].add(_currentTotal(i) + gain);
      }
      rounds++;
      _recomputeStatuses();
      _persist();
    });
  }

  /// Нижняя панель «Порядок выхода» — тап по игрокам в порядке, как вышли.
  Future<void> _pickFinishOrder() async {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.players.length;
    final order = <int>[];
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr('finish_order_title'),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('finish_order_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < n; i++)
                  Builder(builder: (_) {
                    final pos = order.indexOf(i);
                    final picked = pos >= 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: picked
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setSheet(() {
                            if (picked) {
                              order.removeAt(pos);
                            } else {
                              order.add(i);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: picked
                                        ? scheme.primary
                                        : scheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    picked ? '${pos + 1}' : '·',
                                    style: TextStyle(
                                      fontFamily: AppTheme.displayFont,
                                      fontWeight: FontWeight.w800,
                                      color: picked
                                          ? scheme.onPrimary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    widget.players[i],
                                    style: TextStyle(
                                      fontFamily: AppTheme.bodyFont,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: picked
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: order.length == n
                        ? () => Navigator.pop(ctx, List<int>.of(order))
                        : null,
                    child: Text(tr('done')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && result.length == n) _addRankingRound(result);
  }

  /// Завершить «Президента»: победитель — наибольшая сумма очков (при ничьей —
  /// ручной выбор).
  void _finishRanking() {
    if (scores.isEmpty || scores.first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('play_round_first'))),
      );
      return;
    }
    int maxC = -1;
    for (int i = 0; i < widget.players.length; i++) {
      if (_currentTotal(i) > maxC) maxC = _currentTotal(i);
    }
    final leaders = [
      for (int i = 0; i < widget.players.length; i++)
        if (_currentTotal(i) == maxC) widget.players[i],
    ];
    if (leaders.length == 1) {
      setState(() {
        _manualWinner = leaders.first;
        _recomputeStatuses();
        _persist();
      });
    } else {
      _pickManualWinner();
    }
  }

  /// Число проигрышей («дурак») игрока [i] в режиме [WinRule.fool] —
  /// это его текущий накопленный счёт.
  int _foolCount(int i) => _currentTotal(i);

  /// Индекс игрока, который чаще всех был «дураком» (или -1, если ещё никто).
  int get _topFoolIndex {
    int idx = -1, mx = 0;
    for (int i = 0; i < widget.players.length; i++) {
      final c = _foolCount(i);
      if (c > mx) {
        mx = c;
        idx = i;
      }
    }
    return idx;
  }

  /// Добавить кон в «Дураке»: отмечаем проигравшего, ему +1 к счётчику.
  void _addFoolLoss(int loserIndex) {
    setState(() {
      for (int i = 0; i < widget.players.length; i++) {
        if (i == loserIndex) {
          scores[i].add(_foolCount(i) + 1);
        } else {
          scores[i].add('—');
        }
      }
      rounds++;
      _recomputeStatuses();
      _persist();
    });
  }

  /// Нижняя панель «Кто проиграл кон?» для «Дурака».
  Future<void> _pickFoolLoser() async {
    final scheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('who_lost_round'),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < widget.players.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.sentiment_very_dissatisfied_rounded,
                                color: scheme.tertiary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                widget.players[i],
                                style: TextStyle(
                                  fontFamily: AppTheme.bodyFont,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '${_foolCount(i)}',
                              style: TextStyle(
                                fontFamily: AppTheme.displayFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _addFoolLoss(picked);
  }

  /// Завершить партию без авто-конца: «Дурак» — по наименьшему числу
  /// проигрышей, остальные ручные — выбором победителя.
  void _finishGame() {
    if (_rule == WinRule.fool) {
      _finishFool();
    } else if (_rule == WinRule.ranking) {
      _finishRanking();
    } else {
      _pickManualWinner();
    }
  }

  /// Завершить «Дурака»: победитель — кто реже всех был дураком. При равенстве
  /// минимума предлагаем выбрать вручную.
  void _finishFool() {
    if (scores.isEmpty || scores.first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('play_round_first'))),
      );
      return;
    }
    int minC = 1 << 30;
    for (int i = 0; i < widget.players.length; i++) {
      if (_foolCount(i) < minC) minC = _foolCount(i);
    }
    final leaders = [
      for (int i = 0; i < widget.players.length; i++)
        if (_foolCount(i) == minC) widget.players[i],
    ];
    if (leaders.length == 1) {
      setState(() {
        _manualWinner = leaders.first;
        _recomputeStatuses();
        _persist();
      });
    } else {
      _pickManualWinner(); // ничья за минимум — пусть выберет сам
    }
  }

  /// Выбор/смена победителя вручную (для [WinRule.manual]). Открывает нижнюю
  /// панель со списком игроков; «снять победителя» возвращает игру в процесс.
  Future<void> _pickManualWinner() async {
    final scheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr('pick_winner'),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              for (final p in widget.players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: p == _manualWinner
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              p == _manualWinner
                                  ? Icons.emoji_events_rounded
                                  : Icons.person_rounded,
                              color: p == _manualWinner
                                  ? const Color(0xFFFFD700)
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontFamily: AppTheme.bodyFont,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: p == _manualWinner
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_manualWinner != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, ''),
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(tr('clear_winner')),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (picked == null) return; // отменили
    setState(() {
      _manualWinner = picked.isEmpty ? null : picked;
      _recomputeStatuses();
      _persist();
    });
  }

  /// Подпись под цифрой на карточке игрока — зависит от правила игры.
  String _cardSubtitle(int index, bool isElim, int total) {
    if (isElim) return tr('eliminated');
    final left = (_target - total).clamp(0, 1 << 30);
    return switch (_rule) {
      WinRule.elimination => trf('to_out', {'n': left}),
      WinRule.raceHigh => trf('to_win', {'n': left}),
      WinRule.lowestAtCap => trf('to_end', {'n': left}),
      WinRule.manual => '',
      // «Дурак»: подпись = сколько раз продул.
      WinRule.fool => trf('times_fool', {'n': total}),
      // «Президент»: титул по текущему месту (после первого кона).
      WinRule.ranking => rounds > 0 ? _rankTitle(index) : '',
      // Phase 10: «фаза N/10» или «Готово!» при прохождении 10-й.
      WinRule.phases =>
        _phaseOf(index) >= 11 ? tr('phase_done') : trf('phase_n', {'n': _phaseDisplay(index)}),
    };
  }

  /// Эффективный итог игрока в ячейке [r]: само значение, если это число,
  /// иначе перенесённый итог (последнее число до пропуска).
  int _effectiveTotalAt(int i, int r) {
    for (int j = r; j >= 0; j--) {
      if (scores[i][j] is int) return scores[i][j] as int;
    }
    return 0;
  }

  /// Накопительный итог игрока [i] ДО раунда [r] (последнее число в столбцах < r).
  int _totalBefore(int i, int r) {
    for (int j = r - 1; j >= 0; j--) {
      if (scores[i][j] is int) return scores[i][j] as int;
    }
    return 0;
  }

  /// Индекс последнего записанного раунда (или -1, если ходов нет).
  int get _lastRoundIndex => scores.isEmpty ? -1 : scores.first.length - 1;

  /// Редактор ВСЕГО раунда [r]. Открывает ввод очков участников этого круга
  /// (экран «Добавить очки»), где обязателен один закрывший раунд с 0 —
  /// поэтому в каждом круге всегда есть победитель, а история остаётся
  /// корректной (нельзя задать очки «как угодно»).
  void editRound(int r, {int? focusPlayer}) {
    if (scores.isEmpty || r < 0 || r >= scores.first.length) return;
    // В «Дураке»/«Президенте»/Phase 10 нет ввода очков — правка так не применима.
    if (_rule == WinRule.fool ||
        _rule == WinRule.ranking ||
        _rule == WinRule.phases) {
      return;
    }

    // Участники круга — кто ещё не вылетел ДО него (в не-вылетных играх — все).
    final participants = <int>[
      for (int i = 0; i < widget.players.length; i++)
        if (_rule != WinRule.elimination || _totalBefore(i, r) < _target) i,
    ];

    // Текущие очки за этот круг (дельты) для участников.
    final initial = <int>[
      for (final i in participants)
        scores[i][r] is int ? (scores[i][r] as int) - _totalBefore(i, r) : 0,
    ];

    // На каком игроке открыть редактор (если тапнули по конкретной карточке).
    final focusPos = focusPlayer == null ? 0 : participants.indexOf(focusPlayer);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddScoresScreen(
          players: [for (final i in participants) widget.players[i]],
          initialScores: initial,
          initialActive: focusPos < 0 ? 0 : focusPos,
          roundLabel: trf('round_n', {'n': r + 1}),
          rule: _rule,
          target: _target,
          onAddScores: (newDeltas) {
            setState(() {
              for (int k = 0; k < participants.length; k++) {
                final i = participants[k];
                final before = _totalBefore(i, r);
                final newDelta = newDeltas[k];
                final shift = (before + newDelta) - _effectiveTotalAt(i, r);
                // 0 за круг = закрывший (победитель круга) → «—».
                scores[i][r] = newDelta == 0 ? '—' : before + newDelta;
                // Сдвигаем последующие итоги игрока на ту же разницу.
                for (int j = r + 1; j < scores[i].length; j++) {
                  if (scores[i][j] is int) {
                    scores[i][j] = (scores[i][j] as int) + shift;
                  }
                }
              }
              _recomputeStatuses();
              _persist();
            });
          },
        ),
      ),
    );
  }

  void _advanceToPreviousPlayer() {
    setState(() {
      do {
        currentPlayerIndex = (currentPlayerIndex - 1 + widget.players.length) %
            widget.players.length;
      } while (eliminatedPlayers.contains(widget.players[currentPlayerIndex]));
    });
    _persist();
  }

  void editLastRoundScores() {
    if (rounds > 0) {
      List<int> lastRoundScores = [];
      for (int i = 0; i < widget.players.length; i++) {
        if (eliminatedPlayers.contains(widget.players[i])) {
          lastRoundScores.add(0);
          continue;
        }

        // Find the last valid score (int) before the last round
        int lastValidScore = 0;
        int lastRoundIndex = scores[i].length - 1;

        // If there's only one score, use it as is
        if (scores[i].length == 1 && scores[i].last is int) {
          lastRoundScores.add(scores[i].last);
          continue;
        }

        // For multiple scores, find the last valid score before the current round
        for (int j = lastRoundIndex - 1; j >= 0; j--) {
          if (scores[i][j] is int) {
            lastValidScore = scores[i][j];
            break;
          }
        }

        // Calculate the score for the last round only (current total - previous total)
        var currentScore = scores[i].last;
        if (currentScore is int) {
          lastRoundScores.add(currentScore - lastValidScore);
        } else {
          lastRoundScores.add(0);
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddScoresScreen(
            players: remainingPlayers,
            initialScores: lastRoundScores,
            rule: _rule,
            target: _target,
            onAddScores: (newScores) {
              setState(() {
                int remainingIndex = 0;
                for (int i = 0; i < widget.players.length; i++) {
                  if (eliminatedPlayers.contains(widget.players[i])) {
                    continue;
                  }
                  if (scores[i].isNotEmpty) {
                    if (newScores[remainingIndex] == 0) {
                      scores[i][scores[i].length - 1] = '—';
                    } else {
                      int lastValidScore = 0;
                      for (int j = scores[i].length - 2; j >= 0; j--) {
                        if (scores[i][j] is int) {
                          lastValidScore = scores[i][j];
                          break;
                        }
                      }
                      scores[i][scores[i].length - 1] =
                          lastValidScore + newScores[remainingIndex];
                    }
                    remainingIndex++;
                  }
                }
                _recomputeStatuses();
                _persist();
              });
            },
          ),
        ),
      );
    }
  }

  void _restartGame() {
    _persist(); // Сохраняем игру перед рестартом
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreBoardScreen(
          players: widget.players,
          // Сохраняем тип игры при перезапуске, иначе новая партия пойдёт
          // по дефолту «вылет до 101».
          profile: widget.profile,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _persist(); // Сохраняем игру при выходе с экрана
    super.dispose();
  }

  // --------------------------- Вспомогательное ---------------------------

  /// Текущий накопленный счёт игрока (последнее целое значение).
  int _currentTotal(int index) {
    for (int j = scores[index].length - 1; j >= 0; j--) {
      if (scores[index][j] is int) return scores[index][j] as int;
    }
    return 0;
  }

  /// Число колонок сетки карточек под количество игроков (2–6).
  int _columnsFor(int n) {
    if (n <= 2) return 2;
    if (n == 4) return 2;
    return 3; // 3, 5, 6
  }

  // ------------------------------- UI -------------------------------

  /// Метрика игрока для текстового итога (число/фаза/титул по правилу).
  String _shareMetric(int i) {
    switch (_rule) {
      case WinRule.phases:
        return _phaseOf(i) >= 11
            ? tr('phase_done')
            : trf('phase_n', {'n': _phaseDisplay(i)});
      case WinRule.ranking:
        return rounds > 0
            ? '${_currentTotal(i)} · ${_rankTitle(i)}'
            : '${_currentTotal(i)}';
      default:
        return '${_currentTotal(i)}';
    }
  }

  /// Текстовый итог партии для шаринга (работает всегда, даже без картинки).
  String _resultSummaryText() {
    final game = widget.profile?.displayName ?? tr('scoreboard');
    final b = StringBuffer()..writeln('🏆 ScoreMaster — $game');
    if (_finished && _winner != null) {
      final label = _rule == WinRule.fool ? tr('least_fool') : tr('winner');
      b.writeln('$label: $_winner');
    }
    b.writeln();
    for (var i = 0; i < widget.players.length; i++) {
      final name = widget.players[i];
      final marks = StringBuffer();
      if (name == _winner) marks.write(' 🏆');
      if (eliminatedPlayers.contains(name)) marks.write(' ⊘');
      b.writeln('• $name — ${_shareMetric(i)}$marks');
    }
    return b.toString().trimRight();
  }

  /// «Поделиться»: рендерит табло в PNG и отправляет вместе с текстом.
  /// Если картинку снять не удалось — делится одним текстом.
  Future<void> _shareResult() async {
    final text = _resultSummaryText();
    try {
      final boundary =
          _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          final dir = await getTemporaryDirectory();
          final file = await File('${dir.path}/scoremaster_result.png')
              .writeAsBytes(data.buffer.asUint8List());
          await Share.shareXFiles([XFile(file.path)], text: text);
          return;
        }
      }
    } catch (_) {
      // Падать на текст — лучше пустого результата.
    }
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFinished = _finished;
    final cols = _columnsFor(widget.players.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile?.displayName ?? tr('scoreboard')),
        actions: [
          IconButton(
            tooltip: tr('share'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _shareResult,
          ),
          // Игры без авто-победителя (Дурак/Бридж/Президент/Кинг) завершаются
          // вручную: фиксируем итог кнопкой. После — можно сменить/снять.
          if (_rule == WinRule.manual ||
              _rule == WinRule.fool ||
              _rule == WinRule.ranking)
            IconButton(
              tooltip: tr('finish_game'),
              icon: Icon(
                Icons.emoji_events_rounded,
                color: _finished ? const Color(0xFFFFD700) : null,
              ),
              onPressed: _finished ? _pickManualWinner : _finishGame,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Обёрнуто в RepaintBoundary с непрозрачным фоном, чтобы при
                  // «Поделиться» отрендерить именно табло (баннер + карточки).
                  RepaintBoundary(
                    key: _boardKey,
                    child: Container(
                      color: scheme.surface,
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isFinished) _winnerBanner(scheme),
                          GridView.count(
                            crossAxisCount: cols,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: cols == 2 ? 1.05 : 0.88,
                            children: List.generate(
                              widget.players.length,
                              (i) => _playerCard(i, cols, scheme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _historyCard(scheme),
                ],
              ),
            ),
          ),
          _actionBar(scheme, isFinished),
        ],
      ),
    );
  }

  Widget _winnerBanner(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events,
              color: scheme.onTertiaryContainer, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rule == WinRule.fool ? tr('least_fool') : tr('winner'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                AutoSizeText(
                  _winner ?? '',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerCard(int index, int cols, ColorScheme scheme) {
    final player = widget.players[index];
    final isElim = eliminatedPlayers.contains(player);
    final total = _currentTotal(index);
    // В «Дураке» нет хода игрока, зато выделяем текущего «Дурака» (чаще всех
    // проигрывал) — красная карточка.
    final isFool = _rule == WinRule.fool && index == _topFoolIndex && total > 0;
    final isCurrent =
        _rule != WinRule.fool && index == currentPlayerIndex && !isElim;

    final Color bg;
    final Color fg;
    if (isElim) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    } else if (isFool) {
      // Текущий «Дурак» — цветом из темы (третичный), не тревожным красным.
      bg = scheme.tertiaryContainer;
      fg = scheme.onTertiaryContainer;
    } else if (isCurrent) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurface;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          // «Дурак»: тап по игроку = «он проиграл кон» (быстрый ввод).
          // «Президент»/Phase 10 — ввод только через нижнюю кнопку (no-op).
          if (_rule == WinRule.fool) {
            _addFoolLoss(index);
          } else if (_rule == WinRule.ranking || _rule == WinRule.phases) {
            // ничего — кон добавляется кнопкой снизу
          } else {
            _editLatestRound(index);
          }
        },
        child: Container(
      padding: EdgeInsets.all(cols == 2 ? 16 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: isFool
            ? Border.all(color: scheme.tertiary, width: 2)
            : isCurrent
                ? Border.all(color: scheme.primary, width: 2)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  player,
                  maxLines: 1,
                  minFontSize: 10,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: fg,
                  ),
                ),
              ),
              if (isCurrent)
                Icon(Icons.play_arrow_rounded, size: 18, color: fg),
              if (isFool)
                Icon(Icons.sentiment_very_dissatisfied_rounded,
                    size: 18, color: fg),
              if (isElim)
                Icon(Icons.do_not_disturb_on,
                    size: 16, color: fg.withValues(alpha: 0.7)),
            ],
          ),
          // Большая цифра: счёт (для Phase 10 — текущая фаза 1..10).
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _rule == WinRule.phases ? '${_phaseDisplay(index)}' : '$total',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 64,
                    height: 1.0,
                    letterSpacing: -2,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
          AutoSizeText(
            _cardSubtitle(index, isElim, total),
            maxLines: 1,
            minFontSize: 9,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12,
              color: fg.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  /// Тап по карточке игрока — быстрая правка последнего круга (с фокусом на
  /// этом игроке). Если ходов ещё нет, подсказываем добавить раунд.
  void _editLatestRound(int playerIndex) {
    if (_lastRoundIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('add_round_first'))),
      );
      return;
    }
    editRound(_lastRoundIndex, focusPlayer: playerIndex);
  }

  Widget _historyCard(ColorScheme scheme) {
    final roundCount = scores.isEmpty ? 0 : scores[0].length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
          if (roundCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr('no_rounds_yet'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Row(
              children: widget.players
                  .map(
                    (p) => Expanded(
                      child: Text(
                        p,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Divider(color: scheme.outlineVariant, height: 16),
            ...List.generate(roundCount, (r) {
              final showDivider = dividerIndices.contains(r + 1);
              return Column(
                children: [
                  Row(
                    children: List.generate(widget.players.length, (i) {
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              editRound(r, focusPlayer: i);
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: _cellContent(i, r, scheme),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (showDivider) _roundSeparator(scheme),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Содержимое ячейки таблицы раундов:
  /// • число — набранные очки (красным жирным, если на этом круге игрок
  ///   перебрал порог — момент проигрыша);
  /// • ромб активным цветом темы — игрок закрыл круг без очков (взял круг);
  /// • красный «минус» — игрок уже выбыл (проиграл) и больше не играет.
  Widget _cellContent(int i, int r, ColorScheme scheme) {
    final value = scores[i][r];
    final size = _textSize.clamp(12, 22).toDouble();

    final elim = _rule == WinRule.elimination;

    // «Дурак»: в ячейке либо «продул этот кон» (крест цветом темы), либо ничего.
    if (_rule == WinRule.fool) {
      if (value is int) {
        return Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child:
              Icon(Icons.close_rounded, size: size + 4, color: scheme.tertiary),
        );
      }
      return Align(
        alignment: Alignment.center,
        heightFactor: 1,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    if (value is int) {
      final busted = elim && value >= _target;
      return Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: size,
          fontWeight: busted ? FontWeight.w800 : FontWeight.w400,
          color: busted ? scheme.error : scheme.onSurface,
        ),
      );
    }

    // Пропуск ('—'): выбыл (только на вылет) — красный «минус»; иначе закрыл
    // круг без очков — фирменный ромб активным цветом темы (для всех правил,
    // не только на вылет — чтобы маркеры были везде, без скучного прочерка).
    final isOut = elim && _effectiveTotalAt(i, r) >= _target;
    if (isOut) {
      return Align(
        alignment: Alignment.center,
        heightFactor: 1,
        child: Icon(
          Icons.remove_circle_rounded,
          size: size + 4,
          color: scheme.error.withValues(alpha: 0.6),
        ),
      );
    }
    final marker = size * 0.95;
    return Align(
      alignment: Alignment.center,
      heightFactor: 1,
      child: Container(
        width: marker,
        height: marker,
        decoration: ShapeDecoration(
          color: scheme.primary,
          // rotation 0 = угол вверх → ромб (а не квадрат, как при rotation 45).
          shape: const StarBorder.polygon(
            sides: 4,
            rotation: 0,
            pointRounding: 0.36,
          ),
        ),
      ),
    );
  }

  /// Разделитель конца «круга» — полного круга ходов всех игроков.
  /// Не касается краёв, по центру бирюзовый кружок (круг закрыт), по бокам
  /// короткие скруглённые линии. Сразу видно, что начался новый круг.
  Widget _roundSeparator(ColorScheme scheme) {
    Widget line() => Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: Row(
        children: [
          line(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          line(),
        ],
      ),
    );
  }

  Widget _actionBar(ColorScheme scheme, bool isFinished) {
    final isFool = _rule == WinRule.fool;
    final isRanking = _rule == WinRule.ranking;
    final isPhases = _rule == WinRule.phases;
    // Игры, завершаемые вручную (Дурак/Президент/Бридж/Кинг).
    final manualLike = isFool || isRanking || _rule == WinRule.manual;

    // Главная (верхняя) кнопка.
    final Widget primary;
    if (isFinished) {
      primary = FilledButton.icon(
        onPressed: _restartGame,
        icon: const Icon(Icons.replay),
        label: Text(tr('play_again')),
      );
    } else if (isFool) {
      primary = FilledButton.icon(
        onPressed: widget.players.length > 1 ? _pickFoolLoser : null,
        icon: const Icon(Icons.add),
        label: Text(tr('add_kon')),
      );
    } else if (isRanking) {
      primary = FilledButton.icon(
        onPressed: widget.players.length > 1 ? _pickFinishOrder : null,
        icon: const Icon(Icons.add),
        label: Text(tr('add_kon')),
      );
    } else if (isPhases) {
      primary = FilledButton.icon(
        onPressed: _pickPhasePassers,
        icon: const Icon(Icons.add),
        label: Text(tr('add_kon')),
      );
    } else {
      primary = FilledButton.icon(
        onPressed: remainingPlayers.length > 1
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddScoresScreen(
                      players: remainingPlayers,
                      rule: _rule,
                      target: _target,
                      onAddScores: addScores,
                    ),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.add),
        label: Text(tr('add_round')),
      );
    }

    // Правая кнопка во втором ряду.
    final Widget secondary;
    if (manualLike) {
      secondary = FilledButton.tonalIcon(
        onPressed: isFinished
            ? _pickManualWinner
            : (canUndo ? _finishGame : null),
        icon: Icon(isFinished
            ? Icons.edit_rounded
            : Icons.emoji_events_rounded),
        label: Text(isFinished ? tr('change_winner') : tr('finish_game')),
      );
    } else {
      // В Phase 10 правка очков не применима — кнопка «Изменить» неактивна.
      secondary = FilledButton.tonalIcon(
        onPressed: (!isPhases && rounds > 0) ? editLastRoundScores : null,
        icon: const Icon(Icons.edit),
        label: Text(tr('edit_action')),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: double.infinity, child: primary),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: canUndo ? undoLastRound : null,
                    icon: const Icon(Icons.undo),
                    label: Text(tr('undo')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: secondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
