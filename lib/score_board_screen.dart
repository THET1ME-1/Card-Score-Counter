import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import 'add_scores_screen.dart';
import 'models/game_session.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';

class ScoreBoardScreen extends StatefulWidget {
  final List<String> players;
  final Map<String, dynamic>? initialData;

  const ScoreBoardScreen({
    super.key,
    required this.players,
    this.initialData,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ScoreBoardScreenState createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  final GameRepository _repo = GameRepository.instance;

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

  @override
  void initState() {
    super.initState();
    _loadTextSize();
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
    } else {
      scores = List.generate(widget.players.length, (_) => []);
      remainingPlayers = List.from(widget.players);
      gameId = DateTime.now().millisecondsSinceEpoch.toString();
    }
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
      );

  /// Сохраняет партию в историю. Пустые партии (без единого очка) не пишутся —
  /// это заодно избавляет от прежнего костыля с удалением «пустых игр».
  Future<void> _persist() async {
    if (scores.every((row) => row.isEmpty)) return;
    await _repo.upsertGame(_session());
  }

  void addScores(List<int> roundScores) {
    setState(() {
      List<String> playersToEliminate = [];
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

        if (scores[i].last is int && scores[i].last >= 101) {
          playersToEliminate.add(widget.players[i]);
        }

        remainingIndex++;
      }

      for (var player in playersToEliminate) {
        remainingPlayers.remove(player);
        eliminatedPlayers.add(player);
      }

      if (remainingPlayers.length == 1) {
        // Начисляем победу один раз за партию.
        if (!winCredited) {
          _repo.adjustWins(remainingPlayers.first, 1);
          winCredited = true;
        }
      } else if (remainingPlayers.isNotEmpty) {
        rounds++;
        if (rounds % remainingPlayers.length == 0) {
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

  void undoLastRound() {
    setState(() {
      if (rounds > 0) {
        // Get the current state of eliminated players before undoing
        final previousEliminatedPlayers = List<String>.from(eliminatedPlayers);
        final previousWinner =
            remainingPlayers.length == 1 ? remainingPlayers.first : null;

        // Remove the last scores
        for (int i = 0; i < widget.players.length; i++) {
          if (scores[i].isNotEmpty) {
            scores[i].removeLast();
          }
        }

        rounds--;
        if (dividerIndices.isNotEmpty && rounds % widget.players.length == 0) {
          dividerIndices.removeLast();
        }

        // Reset the player lists
        eliminatedPlayers.clear();
        remainingPlayers.clear();

        // Check each player's total score to determine elimination
        for (int i = 0; i < widget.players.length; i++) {
          bool isEliminated = false;

          // Find the last valid score (int) for this player
          int lastValidScore = 0;
          for (int j = scores[i].length - 1; j >= 0; j--) {
            if (scores[i][j] is int) {
              lastValidScore = scores[i][j];
              break;
            }
          }

          // Check if player was previously eliminated or has a score >= 101
          if (previousEliminatedPlayers.contains(widget.players[i]) ||
              (scores[i].isNotEmpty && lastValidScore >= 101)) {
            eliminatedPlayers.add(widget.players[i]);
            isEliminated = true;
          }

          if (!isEliminated) {
            remainingPlayers.add(widget.players[i]);
          }
        }

        // If all players are eliminated, something went wrong - reset to initial state
        if (remainingPlayers.isEmpty && widget.players.isNotEmpty) {
          remainingPlayers = List.from(widget.players);
          eliminatedPlayers.clear();
        }

        // Партия была завершена, а после отмены снова продолжается —
        // снимаем ранее начисленную победу, чтобы не задвоить счётчик.
        if (winCredited &&
            previousWinner != null &&
            remainingPlayers.length != 1) {
          _repo.adjustWins(previousWinner, -1);
          winCredited = false;
        }

        _persist();
        _advanceToPreviousPlayer();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFinished = remainingPlayers.length == 1;
    final cols = _columnsFor(widget.players.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Табло')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  'Победитель',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                AutoSizeText(
                  remainingPlayers.first,
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
    final isCurrent = index == currentPlayerIndex && !isElim;
    final total = _currentTotal(index);

    final Color bg;
    final Color fg;
    if (isElim) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    } else if (isCurrent) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurface;
    }

    return Container(
      padding: EdgeInsets.all(cols == 2 ? 16 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        border: isCurrent
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
              if (isElim)
                Icon(Icons.do_not_disturb_on,
                    size: 16, color: fg.withValues(alpha: 0.7)),
            ],
          ),
          // Большая цифра счёта — масштабируется под размер карточки.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$total',
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
            isElim ? 'Выбыл' : 'до вылета: ${101 - total}',
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
    );
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
            'История раундов',
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
                'Раундов пока нет — добавьте первый.',
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
                      final value = scores[i][r];
                      final isSkip = value == '—';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            isSkip ? '—' : '$value',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: _textSize.clamp(12, 22).toDouble(),
                              color: isSkip
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (showDivider)
                    Divider(color: scheme.outlineVariant, height: 14),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _actionBar(ColorScheme scheme, bool isFinished) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: isFinished
                  ? FilledButton.icon(
                      onPressed: _restartGame,
                      icon: const Icon(Icons.replay),
                      label: const Text('Играть заново'),
                    )
                  : FilledButton.icon(
                      onPressed: remainingPlayers.length > 1
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddScoresScreen(
                                    players: remainingPlayers,
                                    onAddScores: addScores,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить раунд'),
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: rounds > 0 ? undoLastRound : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Отменить'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: rounds > 0 ? editLastRoundScores : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('Изменить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
