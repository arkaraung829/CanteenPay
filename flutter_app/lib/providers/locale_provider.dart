import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app locale (English / Myanmar).
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isMyanmar => _locale.languageCode == 'my';

  /// Load saved locale from prefs.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    _locale = Locale(code);
    notifyListeners();
  }

  /// Toggle between English and Myanmar.
  Future<void> toggle() async {
    _locale = isMyanmar ? const Locale('en') : const Locale('my');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _locale.languageCode);
    notifyListeners();
  }

  /// Set a specific locale.
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }
}
