import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invite_cache.dart';

void main() {
  test('returns cache when fresh result is empty', () {
    final cached = [
      {
        'id': 'invite-joined',
        'host_user_id': 'host-1',
        'invite_members': [
          {'user_id': 'me', 'status': 'accepted'}
        ],
      }
    ];

    final result = preserveInvitesWithCache(
      freshInvites: const [],
      cachedInvites: cached,
      currentUserId: 'me',
      optimisticJoinedInviteIds: const {},
    );

    expect(result, hasLength(1));
    expect(result.first['id'], 'invite-joined');
  });

  test('preserves cached joined invites missing from fresh data', () {
    final fresh = [
      {'id': 'invite-open', 'invite_members': const []}
    ];
    final cached = [
      {'id': 'invite-open', 'invite_members': const []},
      {
        'id': 'invite-joined',
        'invite_members': [
          {'user_id': 'me', 'status': 'accepted'}
        ],
      },
    ];

    final result = preserveInvitesWithCache(
      freshInvites: fresh,
      cachedInvites: cached,
      currentUserId: 'me',
      optimisticJoinedInviteIds: const {},
    );

    final ids = result.map((invite) => invite['id']).toList();
    expect(ids, containsAll(['invite-open', 'invite-joined']));
  });

  test('preserves cached invite not joined by current user for same user', () {
    final fresh = [
      {'id': 'invite-open', 'invite_members': const []}
    ];
    final cached = [
      {'id': 'invite-open', 'invite_members': const []},
      {
        'id': 'invite-other',
        'invite_members': [
          {'user_id': 'someone-else', 'status': 'accepted'}
        ],
      },
    ];

    final result = preserveInvitesWithCache(
      freshInvites: fresh,
      cachedInvites: cached,
      currentUserId: 'me',
      optimisticJoinedInviteIds: const {},
    );

    final ids = result.map((invite) => invite['id']).toList();
    expect(ids, containsAll(['invite-open', 'invite-other']));
  });

  test('mergeInvitesById adds missing invite ids from extra list', () {
    final base = [
      {'id': 'invite-open'}
    ];
    final extra = [
      {'id': 'invite-joined'}
    ];

    final result = mergeInvitesById(baseInvites: base, extraInvites: extra);
    final ids = result.map((invite) => invite['id']).toList();
    expect(ids, containsAll(['invite-open', 'invite-joined']));
  });

  test('mergeInvitesById overwrites base invite when id already exists', () {
    final base = [
      {'id': 'invite-1', 'place': 'Old'}
    ];
    final extra = [
      {'id': 'invite-1', 'place': 'New'}
    ];

    final result = mergeInvitesById(baseInvites: base, extraInvites: extra);
    expect(result, hasLength(1));
    expect(result.first['place'], 'New');
  });

  test('does not preserve unknown cache entries when current user id is empty', () {
    final fresh = [
      {'id': 'invite-open', 'invite_members': const []}
    ];
    final cached = <Map<String, dynamic>>[
      {'id': 'invite-open', 'invite_members': const []},
      {
        'id': 'invite-joined',
        'invite_members': [
          {'user_id': 'me', 'status': 'accepted'}
        ],
      },
      {
        'id': 'invite-other',
        'invite_members': const [],
      },
    ];

    final result = preserveInvitesWithCache(
      freshInvites: fresh,
      cachedInvites: cached,
      currentUserId: '',
      optimisticJoinedInviteIds: const {},
    );

    final ids = result.map((invite) => invite['id']).toList();
    expect(ids, equals(['invite-open']));
  });

  test('preserves missing cached invites via joined_by_current_user flag', () {
    final fresh = [
      {'id': 'invite-open', 'invite_members': const []}
    ];
    final cached = [
      {'id': 'invite-open', 'invite_members': const []},
      {
        'id': 'invite-joined',
        'joined_by_current_user': true,
        'invite_members': const [],
      },
    ];

    final result = preserveInvitesWithCache(
      freshInvites: fresh,
      cachedInvites: cached,
      currentUserId: 'me',
      optimisticJoinedInviteIds: const {},
    );

    final ids = result.map((invite) => invite['id']).toList();
    expect(ids, contains('invite-joined'));
  });

  test('preserves my cached invites when fresh result is empty', () {
    final cached = [
      {
        'id': 'invite-mine',
        'host_user_id': 'me',
        'invite_members': const [],
      }
    ];

    final result = preserveInvitesWithCache(
      freshInvites: const [],
      cachedInvites: cached,
      currentUserId: 'me',
      optimisticJoinedInviteIds: const {},
    );

    expect(result.map((invite) => invite['id']).toList(), ['invite-mine']);
  });
}
