import 'package:flutter/material.dart';

import '../services/game_repository.dart';

/// Один язык интерфейса: код и родное название (для списка выбора).
class AppLanguage {
  final String code;
  final String nativeName;
  const AppLanguage(this.code, this.nativeName);
}

/// Единый центр языков приложения.
///
/// Хранит выбранный язык интерфейса, кладёт его в [GameRepository] и оповещает
/// слушателей. `MaterialApp` слушает контроллер и пересобирает всё дерево —
/// строки через [tr] сразу переключаются. Добавить язык = добавить запись в
/// [languages] и карту переводов в `translations.dart`.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  final GameRepository _repo = GameRepository.instance;

  /// Поддерживаемые языки (порядок = порядок в списке выбора). Базовые ru/en
  /// лежат в strings.dart, остальные — в translations.dart.
  static const List<AppLanguage> languages = [
    AppLanguage('ru', 'Русский'),
    AppLanguage('en', 'English'),
    AppLanguage('de', 'Deutsch'),
    AppLanguage('fr', 'Français'),
    AppLanguage('es', 'Español'),
    AppLanguage('it', 'Italiano'),
    AppLanguage('pt', 'Português'),
  ];

  static List<Locale> get supported =>
      [for (final l in languages) Locale(l.code)];

  static Set<String> get _codes => {for (final l in languages) l.code};

  String _code = 'ru';
  bool _loaded = false;

  String get code => _code;
  Locale get locale => Locale(_code);
  bool get isLoaded => _loaded;

  /// Подгружает сохранённый язык. Вызывается один раз до `runApp`.
  Future<void> load() async {
    final stored = await _repo.languageCode();
    if (stored != null && _codes.contains(stored)) {
      _code = stored;
    } else {
      // Первый запуск — берём системный язык, если он поддержан, иначе русский.
      final sys =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _code = _codes.contains(sys) ? sys : 'ru';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setCode(String code) async {
    if (code == _code || !_codes.contains(code)) return;
    _code = code;
    notifyListeners();
    await _repo.setLanguageCode(code);
  }
}
