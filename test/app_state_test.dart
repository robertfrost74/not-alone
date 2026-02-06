import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasLocationOrCity is true when city set', () {
    final state = AppState();
    state.setCity('Stockholm');
    expect(state.hasLocationOrCity, true);
  });

  test('hasLocationOrCity is true when location set', () {
    final state = AppState();
    state.setLocation(lat: 59.0, lon: 18.0);
    expect(state.hasLocationOrCity, true);
  });
}
