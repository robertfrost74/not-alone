class InviteMember {
  final String? id;
  final String? userId;
  final String? status;

  const InviteMember({
    required this.id,
    required this.userId,
    required this.status,
  });

  factory InviteMember.fromMap(Map<String, dynamic> map) {
    return InviteMember(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString(),
      status: map['status']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
    };
  }
}

class Invite {
  final String id;
  final String? hostUserId;
  final int? maxParticipants;
  final String? targetGender;
  final int? ageMin;
  final int? ageMax;
  final String? createdAt;
  final String? activity;
  final String? mode;
  final String? energy;
  final String? talkLevel;
  final int? duration;
  final String? place;
  final String? meetingTime;
  final String? groupId;
  final String groupName;
  final List<InviteMember> inviteMembers;
  final bool joinedByCurrentUser;

  const Invite({
    required this.id,
    required this.hostUserId,
    required this.maxParticipants,
    required this.targetGender,
    required this.ageMin,
    required this.ageMax,
    required this.createdAt,
    required this.activity,
    required this.mode,
    required this.energy,
    required this.talkLevel,
    required this.duration,
    required this.place,
    required this.meetingTime,
    required this.groupId,
    required this.groupName,
    required this.inviteMembers,
    required this.joinedByCurrentUser,
  });

  factory Invite.fromMap(
    Map<String, dynamic> map, {
    bool joinedByCurrentUser = false,
  }) {
    final membersRaw = map['invite_members'];
    final members = <InviteMember>[];
    if (membersRaw is List) {
      for (final item in membersRaw) {
        if (item is Map<String, dynamic>) {
          members.add(InviteMember.fromMap(item));
        } else if (item is Map) {
          members.add(InviteMember.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final group = map['groups'];
    final groupName = group is Map<String, dynamic>
        ? (group['name'] ?? '').toString()
        : group is Map
            ? (group['name'] ?? '').toString()
            : (map['group_name'] ?? '').toString();

    return Invite(
      id: (map['id'] ?? '').toString(),
      hostUserId: map['host_user_id']?.toString(),
      maxParticipants: (map['max_participants'] as num?)?.toInt() ??
          int.tryParse(map['max_participants']?.toString() ?? ''),
      targetGender: map['target_gender']?.toString(),
      ageMin:
          (map['age_min'] as num?)?.toInt() ?? int.tryParse(map['age_min']?.toString() ?? ''),
      ageMax:
          (map['age_max'] as num?)?.toInt() ?? int.tryParse(map['age_max']?.toString() ?? ''),
      createdAt: map['created_at']?.toString(),
      activity: map['activity']?.toString(),
      mode: map['mode']?.toString(),
      energy: map['energy']?.toString(),
      talkLevel: map['talk_level']?.toString(),
      duration: (map['duration'] as num?)?.toInt() ??
          int.tryParse(map['duration']?.toString() ?? ''),
      place: map['place']?.toString(),
      meetingTime: map['meeting_time']?.toString(),
      groupId: map['group_id']?.toString(),
      groupName: groupName,
      inviteMembers: members,
      joinedByCurrentUser:
          joinedByCurrentUser || map['joined_by_current_user'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'host_user_id': hostUserId,
      'max_participants': maxParticipants,
      'target_gender': targetGender,
      'age_min': ageMin,
      'age_max': ageMax,
      'created_at': createdAt,
      'activity': activity,
      'mode': mode,
      'energy': energy,
      'talk_level': talkLevel,
      'duration': duration,
      'place': place,
      'meeting_time': meetingTime,
      'group_id': groupId,
      'groups': {'name': groupName},
      'group_name': groupName,
      'invite_members': inviteMembers.map((m) => m.toMap()).toList(),
      'joined_by_current_user': joinedByCurrentUser,
    };
  }
}
