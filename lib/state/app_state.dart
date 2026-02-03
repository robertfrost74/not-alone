import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  Locale _locale = const Locale('sv');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
