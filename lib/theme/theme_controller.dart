import 'package:flutter/material.dart';

import '../services/game_repository.dart';
import 'app_theme.dart';

/// Единый центр цветов приложения.
///
/// Хранит выбранный пользователем seed-цвет и режим (тёмный/светлый), кладёт их
/// в [GameRepository] и оповещает слушателей. `MaterialApp` слушает контроллер и
/// перестраивает тему на лету — менять цвет можно из любого экрана через
/// [ThemeController.instance], без проброса колбэков по дереву.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final GameRepository _repo = GameRepository.instance;

  Color _seedColor = AppTheme.defaultSeed;
  bool _isDark = true;
  bool _useDynamic = false;
  bool _loaded = false;

  Color get seedColor => _seedColor;
  bool get isDark => _isDark;

  /// Режим Material You — брать цвет из системных обоев (Android 12+).
  bool get useDynamicColor => _useDynamic;
  bool get isLoaded => _loaded;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Цвет совпадает со стандартным бирюзовым?
  bool get isDefaultSeed =>
      _seedColor.toARGB32() == AppTheme.defaultSeed.toARGB32();

  /// Подгружает сохранённые настройки. Вызывается один раз до `runApp`.
  Future<void> load() async {
    final stored = await _repo.seedColorValue();
    _seedColor = stored == null ? AppTheme.defaultSeed : Color(stored);
    _isDark = await _repo.isDarkTheme();
    _useDynamic = await _repo.dynamicColorEnabled();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setUseDynamicColor(bool value) async {
    if (value == _useDynamic) return;
    _useDynamic = value;
    notifyListeners();
    await _repo.setDynamicColorEnabled(value);
  }

  Future<void> setSeedColor(Color color) async {
    if (color.toARGB32() == _seedColor.toARGB32()) return;
    _seedColor = color;
    notifyListeners();
    await _repo.setSeedColorValue(color.toARGB32());
  }

  Future<void> resetSeedColor() => setSeedColor(AppTheme.defaultSeed);

  Future<void> setDark(bool value) async {
    if (value == _isDark) return;
    _isDark = value;
    notifyListeners();
    await _repo.setDarkTheme(value);
  }
}
