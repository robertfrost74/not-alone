import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invites_repository.dart';

class _TestInvitesRepository extends InvitesRepository {
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchOpenInvitesRaw(
      {int limit = 50}) async {
    calls += 1;
    if (calls == 1) {
      throw Exception('SocketException: failed');
    }
    return [];
  }
}

void main() {
  test('fetchOpenInvites retries on network errors', () async {
    final repo = _TestInvitesRepository();
    final result = await repo.fetchOpenInvites();
    expect(result, isEmpty);
    expect(repo.calls, 2);
  });
}
