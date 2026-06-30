import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/game_session.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Нижняя панель «Поделиться итогом»: показывает красивую брендовую карточку
/// результата партии и отправляет её картинкой (через системный шер).
class ShareResultSheet extends StatefulWidget {
  final GameSession game;
  final String gameTypeName;

  const ShareResultSheet({
    super.key,
    required this.game,
    required this.gameTypeName,
  });

  static Future<void> show(
    BuildContext context, {
    required GameSession game,
    required String gameTypeName,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          ShareResultSheet(game: game, gameTypeName: gameTypeName),
    );
  }

  @override
  State<ShareResultSheet> createState() => _ShareResultSheetState();
}

class _ShareResultSheetState extends State<ShareResultSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  static const List<Color> _palette = [
    Color(0xFF26C6DA),
    Color(0xFFFFB300),
    Color(0xFF7E57C2),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFFF7043),
  ];

  int _finalTotal(int i) {
    final row = widget.game.scores;
    if (i >= row.length) return 0;
    for (var j = row[i].length - 1; j >= 0; j--) {
      final v = row[i][j];
      if (v is int) return v;
    }
    return 0;
  }

  /// Игроки в порядке показа: победитель сверху, остальные — как были.
  List<int> _order() {
    final n = widget.game.players.length;
    final idx = List<int>.generate(n, (i) => i);
    final w = widget.game.winner;
    idx.sort((a, b) {
      final aw = widget.game.players[a] == w ? 0 : 1;
      final bw = widget.game.players[b] == w ? 0 : 1;
      return aw.compareTo(bw);
    });
    return idx;
  }

  String _summaryText() {
    final w = widget.game.winner;
    final date = longDate(widget.game.date);
    final head = '${widget.gameTypeName} · $date';
    if (w != null && w.isNotEmpty) {
      return '$head\n🏆 $w\n— ScoreMaster';
    }
    return '$head\n— ScoreMaster';
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          final dir = await getTemporaryDirectory();
          final file = await File('${dir.path}/scoremaster_share.png')
              .writeAsBytes(data.buffer.asUint8List());
          await Share.shareXFiles([XFile(file.path)], text: _summaryText());
          if (mounted) Navigator.pop(context);
          return;
        }
      }
      await Share.share(_summaryText());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            // Сама карточка (её и снимаем в PNG).
            RepaintBoundary(
              key: _cardKey,
              child: _ResultCard(
                game: widget.game,
                gameTypeName: widget.gameTypeName,
                order: _order(),
                finalTotal: _finalTotal,
                palette: _palette,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(tr('share')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Брендовая карточка результата (фиксированный дизайн для красивого PNG).
class _ResultCard extends StatelessWidget {
  final GameSession game;
  final String gameTypeName;
  final List<int> order;
  final int Function(int) finalTotal;
  final List<Color> palette;

  const _ResultCard({
    required this.game,
    required this.gameTypeName,
    required this.order,
    required this.finalTotal,
    required this.palette,
  });

  static const Color _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final winner = game.winner;
    final shown = order.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.surfaceContainerHigh,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Бренд.
          Row(
            children: [
              Icon(Icons.style_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'ScoreMaster',
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                longDate(game.date),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            gameTypeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: scheme.onSurface,
            ),
          ),
          if (winner != null && winner.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: _gold, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tr('winner')}: $winner',
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
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Итоговые позиции игроков.
          for (var rank = 0; rank < shown.length; rank++)
            _row(scheme, rank, shown[rank]),
          const SizedBox(height: 6),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${game.players.length} ${tr('players_label').toLowerCase()} · '
                '${tr('rounds_played').toLowerCase()}: ${game.rounds}',
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (game.durationMs > 0)
                Text(
                  humanDuration(game.duration),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(ColorScheme scheme, int rank, int playerIndex) {
    final name = game.players[playerIndex];
    final isWinner = name == game.winner;
    final isOut = game.eliminatedPlayers.contains(name);
    final color = palette[playerIndex % palette.length];
    final total = finalTotal(playerIndex);
    final hasPoints = game.scores.isNotEmpty &&
        playerIndex < game.scores.length &&
        game.scores[playerIndex].any((v) => v is int);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: isWinner
                ? const Icon(Icons.emoji_events_rounded, size: 18, color: _gold)
                : Text(
                    '${rank + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
                color: scheme.onSurface,
                decoration: isOut ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (hasPoints)
            Text(
              '$total',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: scheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}
