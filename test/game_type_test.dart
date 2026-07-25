import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/models/game_profile.dart';

void main() {
  test('партия с тегом сохраняет свой тип', () {
    expect(gameTypeIdFor('g1', const {'g1': 'durak'}), 'durak');
  });

  test('партия без тега считается игрой по умолчанию — 101', () {
    // Партии, начатые до тегирования (или потерявшие тег), шли по правилу
    // «вылет до 101». Без этого они выпадали из статистики и сравнения.
    expect(gameTypeIdFor('g1', const {}), kDefaultGameId);
    expect(kDefaultGameId, 'g101');
  });

  test('сравнение с партиями того же типа видит нетегированные партии', () {
    // Симптом бага: в аналитике «Сравнение с другими» не находило ни одной
    // партии, потому что тег был только у части.
    const types = {'a': 'g101'};
    final sameType = ['a', 'b', 'c']
        .where((id) => gameTypeIdFor(id, types) == 'g101')
        .length;
    expect(sameType, 3);
  });

  test('явный тег другого режима не подменяется дефолтом', () {
    const types = {'v': 'volleyball'};
    expect(gameTypeIdFor('v', types), 'volleyball');
  });
}
