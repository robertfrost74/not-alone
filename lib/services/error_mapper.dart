import 'package:supabase_flutter/supabase_flutter.dart';

String mapSupabaseError(
  Object error, {
  required bool isSv,
  required String fallbackEn,
  required String fallbackSv,
}) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == '23505') {
      return isSv ? 'Du är redan med i inbjudan' : 'You already joined';
    }
    if (code == '23503') {
      return isSv ? 'Kopplad data saknas' : 'Related data is missing';
    }
    if (error.message.isNotEmpty) {
      return error.message;
    }
  }
  return isSv ? fallbackSv : fallbackEn;
}
