import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';

/// Нижняя панель выбора игры. Возвращает id выбранной игры (или null).
Future<String?> showGamePicker(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _GamePickerSheet(),
  );
}

class _GamePickerSheet extends StatefulWidget {
  const _GamePickerSheet();

  @override
  State<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<_GamePickerSheet> {
  final GameRepository _repo = GameRepository.instance;
  List<GameProfile> _custom = [];
  String _selected = 'g101';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final custom = await _repo.customGames();
    final sel = await _repo.selectedGameId();
    if (!mounted) return;
    setState(() {
      _custom = custom;
      _selected = sel;
    });
  }

  Future<void> _createOrEdit([GameProfile? existing]) async {
    final result = await showModalBottomSheet<GameProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _GameEditorSheet(existing: existing),
    );
    if (result == null) return;
    final list = [..._custom];
    final idx = list.indexWhere((g) => g.id == result.id);
    if (idx >= 0) {
      list[idx] = result;
    } else {
      list.add(result);
    }
    await _repo.saveCustomGames(list);
    await _load();
  }

  Future<void> _deleteCustom(GameProfile g) async {
    final list = _custom.where((x) => x.id != g.id).toList();
    await _repo.saveCustomGames(list);
    await _load();
  }

  /// «Что сыграть?» — выбирает случайную игру (встроенную или свою) и закрывает
  /// пикер с её id.
  void _pickRandomGame() {
    final all = [...kBuiltInGames, ..._custom];
    if (all.isEmpty) return;
    HapticFeedback.mediumImpact();
    final pick = all[Random().nextInt(all.length)];
    Navigator.pop(context, pick.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('choose_game'),
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRandomGame,
                  icon: const Icon(Icons.casino_rounded, size: 18),
                  label: Text(tr('random_game')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in kBuiltInGames) _gameTile(g, scheme),
                  for (final g in _custom) _gameTile(g, scheme, custom: true),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _createOrEdit(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('add_game')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameTile(GameProfile g, ColorScheme scheme, {bool custom = false}) {
    final selected = g.id == _selected;
    final desc = _ruleShort(g);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop(context, g.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.style_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.displayName,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      Text(
                        desc,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12,
                          color: selected
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (custom) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    onPressed: () => _createOrEdit(g),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_rounded,
                        size: 20, color: scheme.error),
                    onPressed: () => _deleteCustom(g),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ruleShort(GameProfile g) {
    final r = switch (g.winRule) {
      WinRule.elimination => tr('rule_elimination'),
      WinRule.raceHigh => tr('rule_racehigh'),
      WinRule.lowestAtCap => tr('rule_lowestatcap'),
      WinRule.manual => tr('rule_manual'),
      WinRule.fool => tr('rule_fool'),
      WinRule.ranking => tr('rule_ranking'),
      WinRule.phases => tr('rule_phases'),
      WinRule.volleyball => tr('rule_volleyball'),
    };
    if (g.target != null && g.target! > 0) {
      return '$r · ${trf('to_target', {'n': g.target!})}';
    }
    return r;
  }
}

/// Редактор своей игры (создание/правка).
class _GameEditorSheet extends StatefulWidget {
  final GameProfile? existing;
  const _GameEditorSheet({this.existing});

  @override
  State<_GameEditorSheet> createState() => _GameEditorSheetState();
}

class _GameEditorSheetState extends State<_GameEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _rules;
  WinRule _rule = WinRule.raceHigh;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(text: e?.target?.toString() ?? '');
    _rules = TextEditingController(text: e?.rulesUrlRu ?? '');
    _rule = e?.winRule ?? WinRule.raceHigh;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final url = _rules.text.trim();
    final profile = GameProfile(
      id: widget.existing?.id ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      winRule: _rule,
      target: _rule == WinRule.manual ||
              _rule == WinRule.fool ||
              _rule == WinRule.ranking ||
              _rule == WinRule.phases
          ? null
          : int.tryParse(_target.text.trim()),
      rulesUrlRu: url.isEmpty ? null : url,
      rulesUrlEn: url.isEmpty ? null : url,
    );
    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                tr(widget.existing == null
                    ? 'new_game_profile'
                    : 'edit_game_profile'),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: tr('game_name'),
                  prefixIcon: const Icon(Icons.style_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('win_rule'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Волейбол — особый встроенный режим со своим табло, в качестве
              // правила для своей игры не предлагаем.
              for (final r in WinRule.values)
                if (r != WinRule.volleyball) _ruleTile(r, scheme),
              if (_rule != WinRule.manual &&
                  _rule != WinRule.fool &&
                  _rule != WinRule.ranking &&
                  _rule != WinRule.phases) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('target_score'),
                    prefixIcon: const Icon(Icons.flag_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _rules,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tr('open_rules'),
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(tr('save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleTile(WinRule r, ColorScheme scheme) {
    final selected = r == _rule;
    final label = switch (r) {
      WinRule.elimination => tr('rule_elimination'),
      WinRule.raceHigh => tr('rule_racehigh'),
      WinRule.lowestAtCap => tr('rule_lowestatcap'),
      WinRule.manual => tr('rule_manual'),
      WinRule.fool => tr('rule_fool'),
      WinRule.ranking => tr('rule_ranking'),
      WinRule.phases => tr('rule_phases'),
      WinRule.volleyball => tr('rule_volleyball'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _rule = r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      color: selected
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
  }
}
