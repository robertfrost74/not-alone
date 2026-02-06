import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('mapSupabaseError maps unique violations', () {
    const error = PostgrestException(
      message: 'duplicate key value violates unique constraint',
      code: '23505',
      details: '',
      hint: '',
    );

    final sv = mapSupabaseError(
      error,
      isSv: true,
      fallbackEn: 'fallback',
      fallbackSv: 'fallback_sv',
    );
    expect(sv, 'Du är redan med i inbjudan');

    final en = mapSupabaseError(
      error,
      isSv: false,
      fallbackEn: 'fallback',
      fallbackSv: 'fallback_sv',
    );
    expect(en, 'You already joined');
  });
}
