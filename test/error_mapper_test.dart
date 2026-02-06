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

  test('mapSupabaseError maps invite_full', () {
    const error = PostgrestException(
      message: 'invite_full',
      code: 'P0001',
      details: '',
      hint: '',
    );

    final sv = mapSupabaseError(
      error,
      isSv: true,
      fallbackEn: 'fallback',
      fallbackSv: 'fallback_sv',
    );
    expect(sv, 'Inbjudan är full');
  });

  test('mapSupabaseError maps invite_closed and not_authenticated', () {
    const closed = PostgrestException(
      message: 'invite_closed',
      code: 'P0001',
      details: '',
      hint: '',
    );
    final closedSv = mapSupabaseError(
      closed,
      isSv: true,
      fallbackEn: 'fallback',
      fallbackSv: 'fallback_sv',
    );
    expect(closedSv, 'Inbjudan är stängd');

    const notAuth = PostgrestException(
      message: 'not_authenticated',
      code: 'P0001',
      details: '',
      hint: '',
    );
    final notAuthEn = mapSupabaseError(
      notAuth,
      isSv: false,
      fallbackEn: 'fallback',
      fallbackSv: 'fallback_sv',
    );
    expect(notAuthEn, 'You need to sign in');
  });

  test('mapSupabaseError maps permission denied', () {
    const err = PostgrestException(
      message: 'permission denied for table invites',
      code: '42501',
      details: '',
      hint: '',
    );
    final en = mapSupabaseError(
      err,
      isSv: false,
      fallbackEn: 'fallback',
      fallbackSv: 'fallback_sv',
    );
    expect(en, 'Permission denied for this action');
  });
}
