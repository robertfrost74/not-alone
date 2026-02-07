import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invite_counts.dart';

void main() {
  test('computeAcceptedCount adds optimistic join when missing', () {
    final count = computeAcceptedCount(
      members: const [],
      inviteId: 'invite-1',
      optimisticJoinedIds: {'invite-1'},
      currentUserId: 'user-1',
    );
    expect(count, 1);
  });

  test('computeAcceptedCount does not double count existing member', () {
    final count = computeAcceptedCount(
      members: const [
        {'user_id': 'user-1', 'status': 'accepted'}
      ],
      inviteId: 'invite-1',
      optimisticJoinedIds: {'invite-1'},
      currentUserId: 'user-1',
    );
    expect(count, 1);
  });
}
