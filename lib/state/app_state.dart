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
  double? _currentLat;
  double? _currentLon;
  String? _city;

  Locale get locale => _locale;
  double? get currentLat => _currentLat;
  double? get currentLon => _currentLon;
  String? get city => _city;
  bool get hasLocationOrCity =>
      (_currentLat != null && _currentLon != null) ||
      (_city != null && _city!.isNotEmpty);

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void setLocation({double? lat, double? lon}) {
    _currentLat = lat;
    _currentLon = lon;
    notifyListeners();
  }

  void setCity(String? city) {
    _city = city?.trim().isEmpty == true ? null : city?.trim();
    notifyListeners();
  }
}

extension AppStateTranslations on AppState {
  bool get isSv => locale.languageCode == 'sv';

  String t(String en, String sv) => isSv ? sv : en;
}
