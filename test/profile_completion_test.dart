import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/profile_completion.dart';

void main() {
  test('checkProfileCompletion detects missing fields', () {
    final result = checkProfileCompletion({});
    expect(result.isComplete, isFalse);
    expect(result.missingFields, contains('username'));
    expect(result.missingFields, contains('age'));
    expect(result.missingFields, contains('gender'));
    expect(result.missingFields, contains('city'));
  });

  test('checkProfileCompletion passes valid profile', () {
    final result = checkProfileCompletion({
      'username': 'rob',
      'age': 28,
      'gender': 'male',
      'city': 'Stockholm',
    });
    expect(result.isComplete, isTrue);
    expect(result.missingFields, isEmpty);
  });
}
