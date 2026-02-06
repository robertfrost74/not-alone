import 'package:flutter/material.dart';

extension SafeNavigation on BuildContext {
  Future<T?> pushSafe<T>(Route<T> route) {
    if (!mounted) return Future.value(null);
    return Navigator.of(this).push(route);
  }

  Future<T?> pushNamedSafe<T>(String routeName, {Object? arguments}) {
    if (!mounted) return Future.value(null);
    return Navigator.of(this).pushNamed(routeName, arguments: arguments);
  }

  Future<T?> pushAndRemoveUntilSafe<T>(
    Route<T> route,
    bool Function(Route<dynamic>) predicate,
  ) {
    if (!mounted) return Future.value(null);
    return Navigator.of(this).pushAndRemoveUntil(route, predicate);
  }

  void pushNamedAndRemoveUntilSafe(
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    if (!mounted) return;
    Navigator.of(this).pushNamedAndRemoveUntil(
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  void popSafe<T extends Object?>([T? result]) {
    if (!mounted) return;
    Navigator.of(this).pop(result);
  }
}
