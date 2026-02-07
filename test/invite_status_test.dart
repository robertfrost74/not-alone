import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/services/invite_status.dart';

void main() {
  test('computeInviteStatus returns started and expired based on meeting time', () {
    final meeting = DateTime(2026, 2, 6, 12, 0);

    final started = computeInviteStatus(
      meetingAt: meeting,
      accepted: 0,
      mode: 'group',
      maxParticipants: 5,
      now: DateTime(2026, 2, 6, 12, 5),
    );
    expect(started, InviteStatus.started);

    final expired = computeInviteStatus(
      meetingAt: meeting,
      accepted: 0,
      mode: 'group',
      maxParticipants: 5,
      now: DateTime(2026, 2, 6, 12, 20),
    );
    expect(expired, InviteStatus.expired);
  });

  test('computeInviteStatus handles capacity for one_to_one and group', () {
    final open = computeInviteStatus(
      meetingAt: null,
      accepted: 1,
      mode: 'one_to_one',
      maxParticipants: null,
      now: DateTime(2026, 2, 6, 12, 0),
    );
    expect(open, InviteStatus.open);

    final fullOneToOne = computeInviteStatus(
      meetingAt: null,
      accepted: 2,
      mode: 'one_to_one',
      maxParticipants: null,
      now: DateTime(2026, 2, 6, 12, 0),
    );
    expect(fullOneToOne, InviteStatus.full);

    final fullGroup = computeInviteStatus(
      meetingAt: null,
      accepted: 3,
      mode: 'group',
      maxParticipants: 3,
      now: DateTime(2026, 2, 6, 12, 0),
    );
    expect(fullGroup, InviteStatus.full);
  });
}
