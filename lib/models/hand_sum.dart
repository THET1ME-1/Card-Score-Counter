import 'package:flutter/foundation.dart';

/// Очки одного игрока, набранные по частям.
///
/// В играх на вылет человек остаётся с горстью карт разного номинала, и в поле
/// нужно вписать их сумму. Считать её в уме над столом — ровно то место, где
/// сбиваются. Поэтому ввод копит слагаемые: набрал число, нажал плюс, набрал
/// следующее, а в ленте видно, из чего сложился итог.
///
/// Значение неизменяемое: каждое нажатие возвращает новое состояние. Так экран
/// не может случайно поправить чужую запись мимо `setState`.
@immutable
class HandSum {
  const HandSum({this.terms = const [], this.text = ''});

  /// Уже отложенные слагаемые — то, что стоит слева в ленте.
  final List<int> terms;

  /// Число, которое набирают прямо сейчас.
  final String text;

  /// Разложить готовое значение обратно в ввод: экран открывают и для правки
  /// уже записанного раунда.
  factory HandSum.of(int value) =>
      value == 0 ? const HandSum() : HandSum(text: value.toString());

  /// Больше четырёх цифр в одном слагаемом не бывает даже в самых длинных
  /// партиях — ограничение осталось от прежнего поля ввода.
  static const int _maxDigits = 4;

  int get _current => int.tryParse(text) ?? 0;

  /// Итог, который уйдёт в раунд. Считается и до нажатия плюса: человек часто
  /// набирает последнее число и сразу жмёт «сохранить».
  int get total => terms.fold(0, (a, b) => a + b) + _current;

  bool get isEmpty => terms.isEmpty && text.isEmpty;

  /// Строка ленты: слагаемые и то, что набирается сейчас.
  String get tape => [...terms.map((t) => t.toString()), if (text.isNotEmpty) text].join(' + ');

  /// Ленту показываем, только когда есть что складывать: ради одного числа
  /// полоса под карточкой лишь занимает место.
  bool get showTape => terms.isNotEmpty;

  HandSum digit(String d) {
    if (text.length >= _maxDigits) return this;
    if (text.isEmpty || text == '0') return HandSum(terms: terms, text: d);
    return HandSum(terms: terms, text: text + d);
  }

  /// Отложить набранное и начать следующее слагаемое. На пустом вводе плюс
  /// ничего не делает — двойное нажатие не должно плодить нули.
  HandSum plus() {
    if (text.isEmpty) return this;
    return HandSum(terms: [...terms, _current], text: '');
  }

  /// Пока число набирается — стираем цифру. Когда ввод пуст — снимаем целиком
  /// последнее слагаемое: ошибся картой, убрал одним нажатием.
  HandSum backspace() {
    if (text.isNotEmpty) {
      return HandSum(terms: terms, text: text.substring(0, text.length - 1));
    }
    if (terms.isEmpty) return this;
    return HandSum(terms: terms.sublist(0, terms.length - 1), text: '');
  }

  HandSum clear() => const HandSum();
}
