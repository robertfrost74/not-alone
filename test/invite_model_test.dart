import 'package:flutter_test/flutter_test.dart';
import 'package:not_alone/models/invite.dart';

void main() {
  test('Invite.fromMap parses nested invite members and group name', () {
    final invite = Invite.fromMap({
      'id': 'invite-1',
      'host_user_id': 'host-1',
      'groups': {'name': 'Team'},
      'invite_members': [
        {'id': 'm-1', 'user_id': 'u-1', 'status': 'accepted'}
      ],
    });

    expect(invite.id, 'invite-1');
    expect(invite.groupName, 'Team');
    expect(invite.inviteMembers, hasLength(1));
    expect(invite.inviteMembers.first.id, 'm-1');
  });

  test('Invite.toMap keeps joined_by_current_user', () {
    const invite = Invite(
      id: 'invite-2',
      hostUserId: 'host-2',
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
      joinedByCurrentUser: true,
    );

    final map = invite.toMap();
    expect(map['id'], 'invite-2');
    expect(map['joined_by_current_user'], true);
  });
}
