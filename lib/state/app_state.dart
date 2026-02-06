import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  AppState() : _locale = _resolveInitialLocale();

  static Locale _resolveInitialLocale() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    const supportedLanguages = {'sv', 'en'};
    if (supportedLanguages.contains(systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }
    return const Locale('en');
  }

  Locale _locale;

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}

extension AppStateTranslations on AppState {
  bool get isSv => locale.languageCode == 'sv';

  String t(String en, String sv) => isSv ? sv : en;
}
