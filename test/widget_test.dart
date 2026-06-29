// Базовый smoke-тест: приложение запускается и отрисовывает навигацию.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:score_master/main.dart';

void main() {
  testWidgets('Приложение запускается и показывает нижнюю навигацию',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CardGameScoreTracker());
    await tester.pump(const Duration(milliseconds: 100));

    // Нижняя навигация (4 вкладки) присутствует — приложение собралось.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
