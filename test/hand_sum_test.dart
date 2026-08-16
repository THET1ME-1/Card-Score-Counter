import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/models/hand_sum.dart';

/// Счёт руки по частям.
///
/// В «101» и Кункене игрок остаётся с горстью разных карт, и в поле нужно
/// вписать их сумму. Считать её в уме над столом — то место, где сбиваются:
/// двенадцать карт, все разного номинала. Поэтому ввод умеет копить слагаемые:
/// набрал число, нажал плюс, набрал следующее.
void main() {
  group('ввод по слагаемым', () {
    test('без плюса ведёт себя как обычное поле', () {
      var s = const HandSum();
      s = s.digit('1').digit('4');
      expect(s.text, '14');
      expect(s.total, 14);
      expect(s.terms, isEmpty);
    });

    test('плюс откладывает набранное и начинает следующее', () {
      final s = const HandSum().digit('1').digit('0').plus().digit('5');
      expect(s.terms, [10]);
      expect(s.text, '5');
      expect(s.total, 15);
    });

    test('итог считается и до нажатия плюса', () {
      // Человек набрал последнее слагаемое и жмёт «сохранить», не закрывая
      // его плюсом. Потерять это число нельзя.
      final s = const HandSum().digit('1').digit('0').plus().digit('8');
      expect(s.total, 18);
    });

    test('плюс на пустом вводе ничего не портит', () {
      final s = const HandSum().plus().plus().digit('7');
      expect(s.terms, isEmpty);
      expect(s.total, 7);
    });

    test('стирание убирает цифру, пока число набирается', () {
      final s = const HandSum().digit('1').digit('2').backspace();
      expect(s.text, '1');
      expect(s.total, 1);
    });

    test('на пустом вводе стирание снимает последнее слагаемое целиком', () {
      // Ошибся картой — снял её одним нажатием, а не тремя.
      final s = const HandSum().digit('1').digit('0').plus().digit('5').plus();
      expect(s.terms, [10, 5]);
      final after = s.backspace();
      expect(after.terms, [10]);
      expect(after.total, 10);
    });

    test('очистка обнуляет и слагаемые', () {
      final s = const HandSum().digit('9').plus().digit('9').clear();
      expect(s.terms, isEmpty);
      expect(s.text, '');
      expect(s.total, 0);
      expect(s.isEmpty, isTrue);
    });

    test('лента показывает слагаемые и то, что набирается сейчас', () {
      final s = const HandSum().digit('1').digit('0').plus().digit('5');
      expect(s.tape, '10 + 5');
      expect(const HandSum().digit('7').tape, '7');
      expect(const HandSum().tape, '');
    });

    test('лента не рисуется, пока слагаемое одно', () {
      // Ради одного числа полоса под карточкой только мешает.
      expect(const HandSum().digit('7').showTape, isFalse);
      expect(const HandSum().digit('7').plus().showTape, isTrue);
    });

    test('готовое значение раскладывается обратно в ввод', () {
      // Экран открывают, чтобы поправить уже записанный раунд.
      final s = HandSum.of(23);
      expect(s.text, '23');
      expect(s.total, 23);
    });

    test('длина одного слагаемого ограничена, как и раньше', () {
      final s = const HandSum().digit('1').digit('2').digit('3').digit('4').digit('5');
      expect(s.text, '1234');
    });
  });
}
