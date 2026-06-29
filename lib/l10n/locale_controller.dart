import 'package:flutter/material.dart';

import '../services/game_repository.dart';

/// Единый центр языков приложения.
///
/// Хранит выбранный язык интерфейса ('ru'/'en'), кладёт его в [GameRepository]
/// и оповещает слушателей. `MaterialApp` слушает контроллер и пересобирает всё
/// дерево — строки через [tr] сразу переключаются. Тот же паттерн, что у
/// ThemeController.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  final GameRepository _repo = GameRepository.instance;

  static const List<Locale> supported = [Locale('ru'), Locale('en')];

  String _code = 'ru';
  bool _loaded = false;

  String get code => _code;
  Locale get locale => Locale(_code);
  bool get isLoaded => _loaded;

  /// Подгружает сохранённый язык. Вызывается один раз до `runApp`.
  Future<void> load() async {
    final stored = await _repo.languageCode();
    if (stored == 'ru' || stored == 'en') {
      _code = stored!;
    } else {
      // Первый запуск — берём системный язык, если это английский.
      final sys =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _code = sys == 'en' ? 'en' : 'ru';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setCode(String code) async {
    if (code == _code || (code != 'ru' && code != 'en')) return;
    _code = code;
    notifyListeners();
    await _repo.setLanguageCode(code);
  }
}
