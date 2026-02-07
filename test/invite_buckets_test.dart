import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invite_buckets.dart';

void main() {
  test('bucketInvites moves optimistic joined invite into joined list', () {
    const currentUserId = 'user-1';
    final inviteA = {
      'id': 'invite-a',
      'host_user_id': 'host-1',
      'group_id': null,
      'invite_members': [],
    };
    final inviteB = {
      'id': 'invite-b',
      'host_user_id': 'host-2',
      'group_id': null,
      'invite_members': [],
    };
    final buckets = bucketInvites(
      activityFiltered: [inviteA, inviteB],
      currentUserId: currentUserId,
      optimisticJoinedIds: {'invite-a'},
      matchesAudience: (_) => true,
    );

    expect(
      buckets.joinedInvites.map((it) => it['id']).toList(),
      contains('invite-a'),
    );
    expect(
      buckets.invitesForMe.map((it) => it['id']).toList(),
      isNot(contains('invite-a')),
    );
  });

  test('bucketInvites separates mine and others by host user id', () {
    const currentUserId = 'me';
    final mine = {
      'id': 'mine-1',
      'host_user_id': 'me',
      'group_id': null,
      'invite_members': [],
    };
    final other = {
      'id': 'other-1',
      'host_user_id': 'someone-else',
      'group_id': null,
      'invite_members': [],
    };

    final buckets = bucketInvites(
      activityFiltered: [mine, other],
      currentUserId: currentUserId,
      optimisticJoinedIds: const {},
      matchesAudience: (_) => true,
    );

    expect(buckets.myInvites.map((it) => it['id']), ['mine-1']);
    expect(buckets.invitesForMe.map((it) => it['id']), ['other-1']);
  });

  test('bucketInvites keeps joined tab via joined_by_current_user flag', () {
    final joined = {
      'id': 'joined-1',
      'host_user_id': 'host-1',
      'group_id': null,
      'joined_by_current_user': true,
      'invite_members': [],
    };
    final other = {
      'id': 'other-1',
      'host_user_id': 'host-2',
      'group_id': null,
      'invite_members': [],
    };

    final buckets = bucketInvites(
      activityFiltered: [joined, other],
      currentUserId: '',
      optimisticJoinedIds: const {},
      matchesAudience: (_) => true,
    );

    expect(buckets.joinedInvites.map((it) => it['id']), ['joined-1']);
    expect(
      buckets.invitesForMe.map((it) => it['id']).toList(),
      isNot(contains('joined-1')),
    );
  });
}
