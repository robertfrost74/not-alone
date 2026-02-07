import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/models/invite.dart';
import 'package:not_alone/services/invites_repository.dart';

class _TestInvitesRepository extends InvitesRepository {
  int calls = 0;

  @override
  Future<List<Invite>> fetchOpenInvitesNearbyTyped({
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
    return const [];
  }

  @override
  Future<List<Invite>> fetchOpenInvitesRawTyped({int limit = 50}) async {
    return const [];
  }
}

class _FallbackInvitesRepository extends InvitesRepository {
  int nearbyCalls = 0;
  int rawCalls = 0;

  @override
  Future<List<Invite>> fetchOpenInvitesNearbyTyped({
    int limit = 50,
    double? lat,
    double? lon,
    int radiusKm = 20,
    String? city,
  }) async {
    nearbyCalls += 1;
    return const [];
  }

  @override
  Future<List<Invite>> fetchOpenInvitesRawTyped({int limit = 50}) async {
    rawCalls += 1;
    return const [
      Invite(
        id: 'fallback-invite',
        hostUserId: null,
        maxParticipants: null,
        targetGender: null,
        ageMin: null,
        ageMax: null,
        createdAt: null,
        activity: null,
        mode: null,
        energy: null,
        talkLevel: null,
        duration: null,
        place: null,
        meetingTime: null,
        groupId: null,
        groupName: '',
        inviteMembers: [],
        joinedByCurrentUser: false,
      )
    ];
  }
}

class _JoinedPagingRepository extends InvitesRepository {
  int memberPageCalls = 0;
  int invitesByIdCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchJoinedInviteMemberRows(
    String userId, {
    required int from,
    required int to,
  }) async {
    memberPageCalls += 1;
    if (from == 0) {
      return [
        {'invite_id': 'id-1'},
        {'invite_id': 'id-2'},
      ];
    }
    if (from == 2) {
      return [
        {'invite_id': 'id-3'},
      ];
    }
    return [];
  }

  @override
  Future<List<Invite>> fetchInvitesByIdsTyped(Set<String> inviteIds) async {
    invitesByIdCalls += 1;
    return inviteIds
        .map((id) => Invite(
              id: id,
              hostUserId: null,
              maxParticipants: null,
              targetGender: null,
              ageMin: null,
              ageMax: null,
              createdAt:
                  DateTime(2026, 2, 7, 10, inviteIds.length).toIso8601String(),
              activity: null,
              mode: null,
              energy: null,
              talkLevel: null,
              duration: null,
              place: null,
              meetingTime: null,
              groupId: null,
              groupName: '',
              inviteMembers: const [],
              joinedByCurrentUser: false,
            ))
        .toList();
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

  test('fetchJoinedInvitesForUser paginates and marks joined flag', () async {
    final repo = _JoinedPagingRepository();
    final result = await repo.fetchJoinedInvitesForUser(
      'user-1',
      limit: 10,
      pageSize: 2,
    );

    expect(repo.memberPageCalls, 2);
    expect(repo.invitesByIdCalls, 2);
    final ids = result.map((invite) => invite['id']).toSet();
    expect(ids, {'id-1', 'id-2', 'id-3'});
    expect(result.every((invite) => invite['joined_by_current_user'] == true), isTrue);
  });
}
