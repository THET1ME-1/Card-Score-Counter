import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';

/// Сборник правил всех игр (встроенных и своих) со ссылками на правила
/// на текущем языке. Открывает их во внешнем браузере.
class GameRulesScreen extends StatefulWidget {
  const GameRulesScreen({super.key});

  @override
  State<GameRulesScreen> createState() => _GameRulesScreenState();
}

class _GameRulesScreenState extends State<GameRulesScreen> {
  final GameRepository _repo = GameRepository.instance;
  List<GameProfile> _custom = [];

  @override
  void initState() {
    super.initState();
    _repo.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _repo.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final custom = await _repo.customGames();
    if (!mounted) return;
    setState(() => _custom = custom);
  }

  Future<void> _openRules(GameProfile g) async {
    final url = g.rulesUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(url)));
    }
  }

  String _ruleDesc(GameProfile g) {
    final base = switch (g.winRule) {
      WinRule.elimination => tr('rule_elimination'),
      WinRule.raceHigh => tr('rule_racehigh'),
      WinRule.lowestAtCap => tr('rule_lowestatcap'),
      WinRule.manual => tr('rule_manual'),
      WinRule.fool => tr('rule_fool'),
      WinRule.ranking => tr('rule_ranking'),
      WinRule.phases => tr('rule_phases'),
    };
    if (g.target != null && g.target! > 0) {
      return '$base · ${trf('to_target', {'n': g.target!})}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('rules'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _sectionHeader(tr('games'), scheme),
          _groupCard(scheme, [
            for (final g in kBuiltInGames) _gameRow(g, scheme),
          ]),
          if (_custom.isNotEmpty) ...[
            _sectionHeader(tr('custom_games'), scheme),
            _groupCard(scheme, [
              for (final g in _custom) _gameRow(g, scheme),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 10),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: scheme.primary,
          ),
        ),
      );

  Widget _groupCard(ColorScheme scheme, List<Widget> children) {
    final withDividers = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        withDividers.add(Divider(
          height: 1,
          thickness: 1,
          indent: 72,
          endIndent: 16,
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ));
      }
      withDividers.add(children[i]);
    }
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Column(children: withDividers),
    );
  }

  Widget _gameRow(GameProfile g, ColorScheme scheme) {
    return InkWell(
      onTap: () => _openRules(g),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.style_rounded,
                  size: 22, color: scheme.onTertiaryContainer),
            ),
            const SizedBox(width: 16),
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
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _ruleDesc(g),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.open_in_new_rounded, size: 20, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
