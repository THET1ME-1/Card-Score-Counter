import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Один участник колеса: имя и цвет сектора.
class WheelPlayer {
  final String name;
  final Color color;
  const WheelPlayer(this.name, this.color);
}

/// Нижняя панель «Кто первый?»: колесо со случайным выбором игрока и монетка
/// (орёл/решка). Чисто для жеребьёвки перед партией.
class TableToolsSheet extends StatelessWidget {
  final List<WheelPlayer> players;
  const TableToolsSheet({super.key, required this.players});

  static Future<void> show(BuildContext context, List<WheelPlayer> players) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TableToolsSheet(players: players),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TableTools(players: players);
  }
}

class _TableTools extends StatefulWidget {
  final List<WheelPlayer> players;
  const _TableTools({required this.players});

  @override
  State<_TableTools> createState() => _TableToolsState();
}

class _TableToolsState extends State<_TableTools>
    with TickerProviderStateMixin {
  final Random _rng = Random();
  int _mode = 0; // 0 — колесо, 1 — монетка

  // Колесо.
  late final AnimationController _wheel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late Animation<double> _wheelAnim =
      AlwaysStoppedAnimation(_rng.nextDouble() * 2 * pi);
  double _rotation = 0;
  String? _winner;
  bool _spinning = false;

  // Монетка.
  late final AnimationController _coin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _heads = true;
  bool _flipping = false;

  @override
  void initState() {
    super.initState();
    _rotation = _rng.nextDouble() * 2 * pi;
    _wheelAnim = AlwaysStoppedAnimation(_rotation);
  }

  @override
  void dispose() {
    _wheel.dispose();
    _coin.dispose();
    super.dispose();
  }

  int _sliceAtTop(double rotation, int n) {
    final slice = 2 * pi / n;
    var a = (-pi / 2 - rotation) % (2 * pi);
    if (a < 0) a += 2 * pi;
    return (a / slice).floor() % n;
  }

  void _spin() {
    if (_spinning || widget.players.length < 2) return;
    HapticFeedback.mediumImpact();
    final n = widget.players.length;
    final extra = (4 + _rng.nextInt(3)) * 2 * pi + _rng.nextDouble() * 2 * pi;
    final target = _rotation + extra;
    setState(() {
      _spinning = true;
      _winner = null;
    });
    _wheelAnim = Tween<double>(begin: _rotation, end: target).animate(
      CurvedAnimation(parent: _wheel, curve: const Cubic(0.12, 0.7, 0.05, 1.0)),
    );
    _wheel.forward(from: 0).whenComplete(() {
      _rotation = target % (2 * pi);
      final idx = _sliceAtTop(target, n);
      HapticFeedback.heavyImpact();
      SoundService.instance.play(Sfx.win);
      setState(() {
        _spinning = false;
        _winner = widget.players[idx].name;
      });
    });
  }

  void _flip() {
    if (_flipping) return;
    HapticFeedback.mediumImpact();
    final result = _rng.nextBool();
    setState(() => _flipping = true);
    _coin.forward(from: 0).whenComplete(() {
      HapticFeedback.heavyImpact();
      SoundService.instance.play(Sfx.point);
      setState(() {
        _flipping = false;
        _heads = result;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
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
            // Переключатель режима.
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.pie_chart_rounded),
                    label: Text(tr('tool_wheel'))),
                ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.monetization_on_rounded),
                    label: Text(tr('tool_coin'))),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 22),
            if (_mode == 0) _wheelView(scheme) else _coinView(scheme),
          ],
        ),
      ),
    );
  }

  // ------------------------------- КОЛЕСО -------------------------------

  Widget _wheelView(ColorScheme scheme) {
    if (widget.players.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(
          tr('select_min_two'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          width: 260,
          height: 270,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AnimatedBuilder(
                  animation: _wheel,
                  builder: (context, _) => Transform.rotate(
                    angle: _spinning ? _wheelAnim.value : _rotation,
                    child: CustomPaint(
                      size: const Size(258, 258),
                      painter: _WheelPainter(widget.players, scheme),
                    ),
                  ),
                ),
              ),
              // Стрелка-указатель сверху.
              Icon(Icons.arrow_drop_down_rounded,
                  size: 44, color: scheme.onSurface),
              // Центральная втулка.
              Positioned(
                top: 12 + 258 / 2 - 18,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant, width: 2),
                  ),
                  child: Icon(Icons.casino_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 30,
          child: _winner == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed_rounded,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      _winner!,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _spinning ? null : _spin,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('spin')),
          ),
        ),
      ],
    );
  }

  // ------------------------------- МОНЕТКА -------------------------------

  Widget _coinView(ColorScheme scheme) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Center(
            child: AnimatedBuilder(
              animation: _coin,
              builder: (context, _) {
                // Несколько полуоборотов; финальная сторона — _heads.
                final t = _coin.value;
                final spins = _flipping ? 6 : 0;
                final angle = (spins * pi) * Curves.easeOut.transform(t);
                final showHeads = (angle / pi).round().isEven ? _heads : !_heads;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(angle),
                  child: _coinFace(scheme, showHeads),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _flipping ? null : _flip,
            icon: const Icon(Icons.flip_camera_android_rounded),
            label: Text(tr('flip')),
          ),
        ),
      ],
    );
  }

  Widget _coinFace(ColorScheme scheme, bool heads) {
    final base = heads ? const Color(0xFFFFD24A) : const Color(0xFFCFD3D6);
    final fg = heads ? const Color(0xFF6B4E00) : const Color(0xFF36404A);
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [base, Color.lerp(base, Colors.black, 0.18)!],
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
        ),
        border: Border.all(color: Color.lerp(base, Colors.black, 0.3)!, width: 4),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(heads ? Icons.emoji_events_rounded : Icons.star_rounded,
              size: 40, color: fg),
          const SizedBox(height: 4),
          Text(
            heads ? tr('heads') : tr('tails'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Рисует колесо: цветные секторы по числу игроков с инициалами по ободу.
class _WheelPainter extends CustomPainter {
  final List<WheelPlayer> players;
  final ColorScheme scheme;
  _WheelPainter(this.players, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final n = players.length;
    final slice = 2 * pi / n;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = players[i].color;
      canvas.drawArc(rect, i * slice, slice, true, paint);
      // Разделители.
      canvas.drawArc(
        rect,
        i * slice,
        slice,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = scheme.surface,
      );
    }

    // Инициалы по центрам секторов.
    for (var i = 0; i < n; i++) {
      final mid = i * slice + slice / 2;
      final name = players[i].name;
      final label = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w800,
            fontSize: n > 8 ? 13 : 16,
            color: ThemeData.estimateBrightnessForColor(players[i].color) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final r = radius * 0.66;
      final pos = Offset(
        center.dx + r * cos(mid) - tp.width / 2,
        center.dy + r * sin(mid) - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }

    // Обод.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = scheme.outlineVariant,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.players != players || old.scheme != scheme;
}
