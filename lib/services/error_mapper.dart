import 'package:supabase_flutter/supabase_flutter.dart';

bool isNetworkError(Object error) {
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed to fetch') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection reset');
}

String mapSupabaseError(
  Object error, {
  required bool isSv,
  required String fallbackEn,
  required String fallbackSv,
}) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final message = error.message;
    if (message == 'invite_full') {
      return isSv ? 'Inbjudan är full' : 'Invite is full';
    }
    if (message == 'invite_closed') {
      return isSv ? 'Inbjudan är stängd' : 'Invite is closed';
    }
    if (message == 'not_authenticated') {
      return isSv ? 'Du behöver logga in' : 'You need to sign in';
    }
    if (code == '23505') {
      return isSv ? 'Du är redan med i inbjudan' : 'You already joined';
    }
    if (code == '23503') {
      return isSv ? 'Kopplad data saknas' : 'Related data is missing';
    }
    if (message.isNotEmpty) {
      return message;
    }
  }
  if (isNetworkError(error)) {
    return isSv ? 'Ingen anslutning. Försök igen.' : 'Offline. Try again.';
  }
  return isSv ? fallbackSv : fallbackEn;
}
