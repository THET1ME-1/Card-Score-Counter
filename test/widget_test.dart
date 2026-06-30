// Базовый smoke-тест: приложение запускается и отрисовывает навигацию.

import 'dart:convert';

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

    // Нижняя навигация присутствует: активная вкладка «Меню» (заливка) и
    // другие вкладки (контур) — приложение собралось.
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('Меню с незавершённой партией строится (баннер «Продолжить»)',
      (WidgetTester tester) async {
    // Регресс: при наличии незавершённой партии плашка делится надвое.
    // Раньше stretch в безграничной по высоте Row ронял билд (меню пустело).
    final profile = jsonEncode({
      'name': 'Саша',
      'color': 0xFF26C6DA,
      'wins': 0,
      'imagePath': null,
    });
    final unfinished = jsonEncode({
      'gameId': 'g1',
      'players': ['Саша', 'Папа'],
      'scores': [
        [20],
        [30],
      ],
      'rounds': 1,
      'remainingPlayers': ['Саша', 'Папа'],
      'eliminatedPlayers': <String>[],
      'dividerIndices': <int>[],
      'currentPlayerIndex': 0,
      'date': '2026-06-30T11:00:00.000',
      'winCredited': false,
      'winnerName': null,
      'durationMs': 5000,
      'playerTimesMs': [3000, 2000],
    });
    SharedPreferences.setMockInitialValues({
      'profiles': [profile],
      'gameHistory': [unfinished],
    });

    await tester.pumpWidget(const CardGameScoreTracker());
    // Даём асинхронной загрузке игр/профилей завершиться и анимациям осесть.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));

    // Меню построилось без исключений, видна кнопка «Продолжить».
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_circle_rounded), findsOneWidget);
  });
}
