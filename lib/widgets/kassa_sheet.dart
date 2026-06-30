import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../services/game_repository.dart';
import '../theme/app_theme.dart';

/// Касса: вводишь итог каждого игрока в деньгах (+выиграл / −проиграл), а внизу
/// считается «кто кому сколько должен» (минимум переводов). Если задан [gameId],
/// суммы сохраняются к партии (переживают «Продолжить»).
class KassaSheet extends StatefulWidget {
  final List<String> players;
  final String? gameId;
  const KassaSheet({super.key, required this.players, this.gameId});

  static Future<void> show(BuildContext context, List<String> players,
      {String? gameId}) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => KassaSheet(players: players, gameId: gameId),
    );
  }

  @override
  State<KassaSheet> createState() => _KassaSheetState();
}

class _Transfer {
  final String from;
  final String to;
  final int amount;
  const _Transfer(this.from, this.to, this.amount);
}

class _KassaSheetState extends State<KassaSheet> {
  static const List<Color> _palette = [
    Color(0xFF26C6DA),
    Color(0xFFFFB300),
    Color(0xFF7E57C2),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFFF7043),
  ];

  late final Map<String, int> _net = {for (final p in widget.players) p: 0};
  late final Map<String, TextEditingController> _ctrls = {
    for (final p in widget.players) p: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final id = widget.gameId;
    if (id == null || id.isEmpty) return;
    final saved = await GameRepository.instance.gameKassa(id);
    if (!mounted || saved.isEmpty) return;
    setState(() {
      saved.forEach((name, v) {
        if (_net.containsKey(name)) {
          _net[name] = v;
          _ctrls[name]?.text = v == 0 ? '' : '$v';
        }
      });
    });
  }

  void _save() {
    final id = widget.gameId;
    if (id != null && id.isNotEmpty) {
      GameRepository.instance.setGameKassa(id, _net);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _sum => _net.values.fold(0, (a, b) => a + b);

  /// Жадный расчёт минимума переводов между должниками и получателями.
  List<_Transfer> _settle() {
    final debtors = <List<dynamic>>[]; // [name, сколько должен (>0)]
    final creditors = <List<dynamic>>[]; // [name, сколько получит (>0)]
    _net.forEach((name, v) {
      if (v < 0) debtors.add([name, -v]);
      if (v > 0) creditors.add([name, v]);
    });
    final out = <_Transfer>[];
    var i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = (debtors[i][1] as int) < (creditors[j][1] as int)
          ? debtors[i][1] as int
          : creditors[j][1] as int;
      if (pay > 0) {
        out.add(_Transfer(
            debtors[i][0] as String, creditors[j][0] as String, pay));
      }
      debtors[i][1] = (debtors[i][1] as int) - pay;
      creditors[j][1] = (creditors[j][1] as int) - pay;
      if (debtors[i][1] == 0) i++;
      if (creditors[j][1] == 0) j++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transfers = _settle();
    final balanced = _sum == 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  Icon(Icons.payments_rounded, color: scheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    tr('kassa'),
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr('kassa_hint'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < widget.players.length; i++)
                _playerRow(scheme, i),
              const SizedBox(height: 8),
              // Итоговый баланс.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: balanced
                      ? scheme.surfaceContainerHighest
                      : scheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('kassa_balance'),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontWeight: FontWeight.w600,
                          color: balanced
                              ? scheme.onSurface
                              : scheme.onErrorContainer,
                        ),
                      ),
                    ),
                    Text(
                      _sum > 0 ? '+$_sum' : '$_sum',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: balanced
                            ? scheme.onSurface
                            : scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Расчёт.
              if (transfers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    tr('kassa_settled'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...transfers.map((t) => _transferRow(scheme, t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerRow(ColorScheme scheme, int i) {
    final name = widget.players[i];
    final color = _palette[i % _palette.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: scheme.onSurface,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _ctrls[name],
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: const InputDecoration(
                isDense: true,
                hintText: '0',
              ),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: scheme.onSurface,
              ),
              onChanged: (v) {
                setState(() => _net[name] = int.tryParse(v) ?? 0);
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _transferRow(ColorScheme scheme, _Transfer t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.from,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded,
                size: 18, color: scheme.primary),
          ),
          Expanded(
            child: Text(
              t.to,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${t.amount}',
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
