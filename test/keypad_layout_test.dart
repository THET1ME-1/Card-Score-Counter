import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/widgets/numeric_keypad.dart';

/// Раскладка клавиатуры на четыре колонки.
///
/// Сторож появился после живого прогона: внешний ряд нижнего блока делил ширину
/// пополам, поэтому кнопка действия занимала половину клавиатуры, цифры 7–9
/// сжимались, а справа от нуля висела дыра. Проверяем именно ширины: они
/// обязаны совпасть у всех рядов.
void main() {
  Future<void> open(WidgetTester tester, {VoidCallback? onPlus}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: NumericKeypad(
            onDigit: (_) {},
            onBackspace: () {},
            onAction: () {},
            onPlus: onPlus,
          ),
        ),
      ),
    ));
  }

  /// Ширина самой клавиши, а не глифа на ней: текст занимает ровно ширину
  /// цифры и о раскладке ничего не говорит.
  double widthOf(WidgetTester tester, String label) => tester
      .getSize(find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first)
      .width;

  testWidgets('цифры всех рядов одной ширины', (tester) async {
    await open(tester, onPlus: () {});
    final base = widthOf(tester, '1');
    for (final d in ['2', '3', '4', '5', '6', '7', '8', '9']) {
      expect(widthOf(tester, d), closeTo(base, 0.5),
          reason: 'цифра $d выбилась из сетки');
    }
  });

  testWidgets('плюс стоит в одной колонке со стиранием', (tester) async {
    await open(tester, onPlus: () {});
    final plus = tester.getRect(find.text('+'));
    final erase = tester.getRect(find.byIcon(Icons.backspace_outlined));
    expect(plus.center.dx, closeTo(erase.center.dx, 0.5));
  });

  testWidgets('ноль занимает три колонки', (tester) async {
    await open(tester, onPlus: () {});
    // Втрое шире цифры плюс два зазора между тремя клавишами: у каждой свой
    // отступ 5, значит на стыках набегает ещё 20.
    expect(widthOf(tester, '0'), closeTo(widthOf(tester, '7') * 3 + 20, 1.5));
  });

  testWidgets('без плюса раскладка прежняя, три колонки', (tester) async {
    await open(tester);
    expect(find.text('+'), findsNothing);
    expect(widthOf(tester, '0'), closeTo(widthOf(tester, '7'), 0.5));
  });
}
