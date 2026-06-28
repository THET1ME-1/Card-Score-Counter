// Базовый smoke-тест: приложение запускается и отрисовывает главный экран.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:score_master/main.dart';

void main() {
  testWidgets('Приложение запускается и показывает главный экран',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CardGameScoreTracker());
    await tester.pumpAndSettle();

    // AppBar главного меню присутствует.
    expect(find.text('Главное меню'), findsOneWidget);
  });
}
