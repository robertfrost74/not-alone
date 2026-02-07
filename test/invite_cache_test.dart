import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invite_cache.dart';

void main() {
  test('returns cache when fresh result is empty', () {
    final cached = [
      {
        'id': 'invite-joined',
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

    expect(result, same(cached));
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

  test('does not preserve cached invite not joined by current user', () {
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
    expect(ids, equals(['invite-open']));
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

  test('preserves missing cached invites when current user id is empty', () {
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
      currentUserId: '',
      optimisticJoinedInviteIds: const {},
    );

    final ids = result.map((invite) => invite['id']).toList();
    expect(ids, contains('invite-joined'));
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
}
