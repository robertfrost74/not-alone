import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invites_repository.dart';

class _TestInvitesRepository extends InvitesRepository {
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchOpenInvitesNearby({
    int limit = 50,
    double? lat,
    double? lon,
    int radiusKm = 20,
    String? city,
  }) async {
    calls += 1;
    if (calls == 1) {
      throw Exception('SocketException: failed');
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOpenInvitesRaw(
      {int limit = 50}) async {
    return [];
  }
}

class _FallbackInvitesRepository extends InvitesRepository {
  int nearbyCalls = 0;
  int rawCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchOpenInvitesNearby({
    int limit = 50,
    double? lat,
    double? lon,
    int radiusKm = 20,
    String? city,
  }) async {
    nearbyCalls += 1;
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOpenInvitesRaw(
      {int limit = 50}) async {
    rawCalls += 1;
    return [
      {'id': 'fallback-invite'}
    ];
  }
}

void main() {
  test('fetchOpenInvites retries on network errors', () async {
    final repo = _TestInvitesRepository();
    final result = await repo.fetchOpenInvites(city: 'Stockholm');
    expect(result, isEmpty);
    expect(repo.calls, 2);
  });

  test('fetchOpenInvites falls back to raw query when nearby is empty', () async {
    final repo = _FallbackInvitesRepository();
    final result = await repo.fetchOpenInvites(city: 'Stockholm');
    expect(repo.nearbyCalls, 1);
    expect(repo.rawCalls, 1);
    expect(result, isNotEmpty);
    expect(result.first['id'], 'fallback-invite');
  });
}
