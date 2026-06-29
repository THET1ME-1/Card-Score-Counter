import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'theme/app_theme.dart';
import 'widgets/numeric_keypad.dart';

class AddScoresScreen extends StatefulWidget {
  final List<String> players;
  final Function(List<int>) onAddScores;
  final List<int> initialScores;

  /// С какого игрока начинать (активная строка).
  final int initialActive;

  /// Заголовок экрана (например «Круг 3» при правке). По умолчанию — добавление.
  final String? roundLabel;

  /// Правило игры — определяет, как вводятся очки: на вылет (КунКен — есть
  /// «закрывший» круг с 0 и кнопка «Вылет») или свободно (гонка/минимум/ручной —
  /// просто очки за раунд каждому).
  final WinRule rule;

  /// Порог очков игры — на него ставит кнопка «Вылет» (по умолчанию 101).
  final int target;

  const AddScoresScreen({
    super.key,
    required this.players,
    required this.onAddScores,
    this.initialScores = const [],
    this.initialActive = 0,
    this.roundLabel,
    this.rule = WinRule.elimination,
    this.target = 101,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AddScoresScreenState createState() => _AddScoresScreenState();
}

class _AddScoresScreenState extends State<AddScoresScreen> {
  late List<String> _values;
  late int _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initialActive.clamp(0, widget.players.length - 1);
    _values = List.generate(
      widget.players.length,
      (i) => widget.initialScores.isNotEmpty && i < widget.initialScores.length
          ? widget.initialScores[i].toString()
          : '',
    );
  }

  /// На вылет (КунКен/101): раунд сохраняется, когда РОВНО ОДИН игрок «закрыл»
  /// круг без очков (0) — победитель круга, — а у ВСЕХ остальных стоит число
  /// больше 0 (штрафные очки). В остальных играх очки свободные — сохранять
  /// можно всегда.
  bool get _canSave {
    if (!_isElimination) return true;
    int zeros = 0;
    for (final v in _values) {
      if (v.isEmpty || v == '0') {
        zeros++;
      } else {
        final n = int.tryParse(v);
        if (n == null || n <= 0) return false;
      }
    }
    return zeros == 1;
  }

  bool get _isElimination => widget.rule == WinRule.elimination;

  void _digit(String d) {
    setState(() {
      final cur = _values[_active];
      if (cur.isEmpty || cur == '0') {
        _values[_active] = d;
      } else if (cur.length < 4) {
        _values[_active] = cur + d;
      }
    });
  }

  void _backspace() {
    setState(() {
      final cur = _values[_active];
      if (cur.isNotEmpty) _values[_active] = cur.substring(0, cur.length - 1);
    });
  }

  void _clear() => setState(() => _values[_active] = '');

  void _next() {
    setState(() => _active = (_active + 1) % widget.players.length);
  }

  void _eliminate(int index) {
    setState(() {
      _values[index] = widget.target.toString();
      _active = index;
    });
  }

  void _submit() {
    final scores = _values.map((v) {
      if (v.isEmpty || v == '0' || v == '-') return 0;
      return int.tryParse(v) ?? 0;
    }).toList();
    widget.onAddScores(scores);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.roundLabel ?? tr('add_scores'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isElimination
                          ? tr('add_scores_hint_elim')
                          : tr('add_scores_hint_points'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              itemCount: widget.players.length,
              itemBuilder: (context, index) => _playerRow(index, scheme),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSave ? _submit : null,
                icon: const Icon(Icons.check),
                label: Text(tr('save_round')),
              ),
            ),
          ),
          SafeArea(
            top: false,
            // Заметный нижний отступ — чтобы нижний ряд не попадал в зону
            // системного жеста «домой».
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 24),
              child: NumericKeypad(
                onDigit: _digit,
                onBackspace: _backspace,
                onClear: _clear,
                actionIcon: Icons.keyboard_arrow_down,
                onAction: widget.players.length > 1 ? _next : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerRow(int index, ColorScheme scheme) {
    final isActive = index == _active;
    final value = _values[index];

    final bg = isActive ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = isActive ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _active = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isActive
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.players[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 13,
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        value.isEmpty ? '0' : value,
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          height: 1.1,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isElimination) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _eliminate(index),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(tr('bust')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
