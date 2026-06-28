import 'package:flutter/material.dart';

import 'models/game_session.dart';
import 'score_board_screen.dart';
import 'services/game_repository.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GameHistoryScreenState createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final GameRepository _repo = GameRepository.instance;

  List<GameSession> _games = [];
  bool _isDescending = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final descending = await _repo.isDescending();
    final games = await _repo.loadGames();
    games.sort((a, b) =>
        descending ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    if (!mounted) return;
    setState(() {
      _isDescending = descending;
      _games = games;
      _loading = false;
    });
  }

  Future<void> _toggleSort() async {
    await _repo.setDescending(!_isDescending);
    await _load();
  }

  Future<void> _deleteGame(GameSession game) async {
    await _repo.deleteGame(game.gameId);
    await _load();
  }

  String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  void _confirmDelete(GameSession game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить эту игру?'),
        content: const Text(
            'Вы уверены, что хотите удалить эту игру из истории?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGame(game);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История игр'),
        actions: [
          IconButton(
            tooltip: _isDescending ? 'Сначала новые' : 'Сначала старые',
            icon: Icon(
                _isDescending ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: _games.isEmpty ? null : _toggleSort,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _games.length,
                  itemBuilder: (context, index) {
                    final game = _games[index];
                    final number =
                        _isDescending ? _games.length - index : index + 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: game.isFinished
                            ? const Icon(Icons.emoji_events,
                                color: Colors.amber)
                            : Icon(Icons.timelapse, color: scheme.outline),
                        title: Text(
                          'Игра $number',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDate(game.date)),
                            const SizedBox(height: 2),
                            Text('Игроки: ${game.players.join(', ')}'),
                            if (game.isFinished)
                              Text(
                                'Победитель: ${game.winner}',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Удалить',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(game),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScoreBoardScreen(
                                players: game.players,
                                initialData: game.toJson(),
                              ),
                            ),
                          ).then((_) => _load());
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 72, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text('История пуста', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Сыграйте первую партию — она появится здесь.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
