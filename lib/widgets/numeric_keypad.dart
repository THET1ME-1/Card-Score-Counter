import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Крупная экранная цифровая клавиатура.
///
/// Делается частью layout (обычно снизу), поэтому ничего не перекрывает и
/// раскладка не «прыгает», как с системной клавиатурой. Кнопки большие — под
/// палец, удобно набирать за столом, передавая телефон. Стиль плоский.
class NumericKeypad extends StatelessWidget {
  /// Нажата цифра ('0'..'9').
  final ValueChanged<String> onDigit;

  /// Стереть последний символ.
  final VoidCallback onBackspace;

  /// Долгое нажатие на «стереть» — очистить полностью.
  final VoidCallback? onClear;

  /// Правая нижняя кнопка действия (готово/далее).
  final VoidCallback? onAction;

  /// Отложить набранное слагаемое и начать следующее.
  ///
  /// Задан — клавиатура становится четырёхколоночной: правый столбец занимают
  /// стирание, плюс и действие во всю высоту двух рядов, а ноль забирает весь
  /// нижний ряд. Не задан — раскладка прежняя, три колонки.
  final VoidCallback? onPlus;

  final IconData actionIcon;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onClear,
    this.onAction,
    this.onPlus,
    this.actionIcon = Icons.check,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget digit(String d) => _KeypadButton(
          onTap: () => onDigit(d),
          semanticLabel: d,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurface,
          child: Text(
            d,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 30,
            ),
          ),
        );

    Widget backspaceKey() => _KeypadButton(
          onTap: onBackspace,
          onLongPress: onClear,
          semanticLabel: MaterialLocalizations.of(context).keyboardKeyBackspace,
          background: scheme.surfaceContainerHigh,
          foreground: scheme.onSurfaceVariant,
          child: const Icon(Icons.backspace_outlined, size: 28),
        );

    Widget actionKey({double? height}) => _KeypadButton(
          onTap: onAction,
          height: height,
          semanticLabel: MaterialLocalizations.of(context).okButtonLabel,
          background: scheme.primary,
          foreground: scheme.onPrimary,
          child: Icon(actionIcon, size: 30),
        );

    if (onPlus != null) {
      // Четыре колонки: цифры слева, справа — стирание, плюс и действие.
      // Действие вытянуто на два ряда: это самая частая кнопка после цифр,
      // и мимо неё труднее промахнуться, чем по обычной.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            for (final d in const ['1', '2', '3']) Expanded(child: digit(d)),
            Expanded(child: backspaceKey()),
          ]),
          Row(children: [
            for (final d in const ['4', '5', '6']) Expanded(child: digit(d)),
            Expanded(
              child: _KeypadButton(
                onTap: onPlus,
                semanticLabel: '+',
                background: scheme.surfaceContainerHigh,
                foreground: scheme.primary,
                child: const Text(
                  '+',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
          ]),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Три доли против одной: колонки обязаны совпасть с рядами
                // выше, иначе цифры сжимаются, а кнопка действия раздувается
                // на половину клавиатуры.
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        for (final d in const ['7', '8', '9'])
                          Expanded(child: digit(d)),
                      ]),
                      Row(children: [Expanded(child: digit('0'))]),
                    ],
                  ),
                ),
                // Одна кнопка ростом в два ряда: 62 + 62 плюс зазор между ними.
                Expanded(child: actionKey(height: 134)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) Expanded(child: digit(d))]),
        Row(
          children: [
            Expanded(
              child: _KeypadButton(
                onTap: onBackspace,
                onLongPress: onClear,
                semanticLabel: MaterialLocalizations.of(context)
                    .keyboardKeyBackspace,
                background: scheme.surfaceContainerHigh,
                foreground: scheme.onSurfaceVariant,
                child: const Icon(Icons.backspace_outlined, size: 28),
              ),
            ),
            Expanded(child: digit('0')),
            Expanded(
              child: _KeypadButton(
                onTap: onAction,
                semanticLabel: MaterialLocalizations.of(context).okButtonLabel,
                background: scheme.primary,
                foreground: scheme.onPrimary,
                child: Icon(actionIcon, size: 30),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Высота кнопки. По умолчанию 62 — общий размер клавиши.
  final double? height;
  final Color background;
  final Color foreground;
  final Widget child;
  final String? semanticLabel;

  const _KeypadButton({
    required this.onTap,
    this.height,
    this.onLongPress,
    required this.background,
    required this.foreground,
    required this.child,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
      padding: const EdgeInsets.all(5),
      child: SizedBox(
        height: height ?? 62,
        child: Material(
          color: enabled ? background : background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            onLongPress: onLongPress,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: foreground),
                child: DefaultTextStyle(
                  style: TextStyle(color: foreground),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Нижняя панель ввода одного значения очков через [NumericKeypad].
/// Возвращает введённое число или null, если отменено.
Future<int?> showScoreInputSheet(
  BuildContext context, {
  required String title,
  required int initial,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ScoreInputSheet(title: title, initial: initial),
  );
}

class _ScoreInputSheet extends StatefulWidget {
  final String title;
  final int initial;

  const _ScoreInputSheet({required this.title, required this.initial});

  @override
  State<_ScoreInputSheet> createState() => _ScoreInputSheetState();
}

class _ScoreInputSheetState extends State<_ScoreInputSheet> {
  late String _value = widget.initial.toString();

  void _digit(String d) {
    setState(() {
      if (_value == '0') {
        _value = d;
      } else if (_value.length < 4) {
        _value += d;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_value.isNotEmpty) {
        _value = _value.substring(0, _value.length - 1);
      }
      if (_value.isEmpty) _value = '0';
    });
  }

  void _clear() => setState(() => _value = '0');

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
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _value,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 48,
                    height: 1.0,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            NumericKeypad(
              onDigit: _digit,
              onBackspace: _backspace,
              onClear: _clear,
              actionIcon: Icons.check,
              onAction: () =>
                  Navigator.pop(context, int.tryParse(_value) ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}
