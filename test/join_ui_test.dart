import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/join_ui.dart';

void main() {
  test('computeJoinUiState marks only matching invite as joining', () {
    final joining = computeJoinUiState(
      inviteId: 'invite-1',
      joiningInviteId: 'invite-1',
      canJoin: true,
      isJoinCooldownActive: false,
      isSv: true,
      defaultLabel: 'Gå med',
    );
    expect(joining.enabled, isFalse);
    expect(joining.label, 'Går med...');

    final other = computeJoinUiState(
      inviteId: 'invite-2',
      joiningInviteId: 'invite-1',
      canJoin: true,
      isJoinCooldownActive: false,
      isSv: true,
      defaultLabel: 'Gå med',
    );
    expect(other.enabled, isTrue);
    expect(other.label, 'Gå med');
  });
}
