class InviteBuckets {
  final List<Map<String, dynamic>> joinedInvites;
  final List<Map<String, dynamic>> myInvites;
  final List<Map<String, dynamic>> invitesForMe;
  final List<Map<String, dynamic>> groupInvites;

  const InviteBuckets({
    required this.joinedInvites,
    required this.myInvites,
    required this.invitesForMe,
    required this.groupInvites,
  });
}

InviteBuckets bucketInvites({
  required List<Map<String, dynamic>> activityFiltered,
  required String currentUserId,
  required Set<String> optimisticJoinedIds,
  required bool Function(Map<String, dynamic>) matchesAudience,
}) {
  final joinedInvites = activityFiltered.where((it) {
    final members =
        (it['invite_members'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final id = it['id']?.toString();
    if (id != null && optimisticJoinedIds.contains(id)) {
      return true;
    }
    return members.any((m) =>
        m['user_id']?.toString() == currentUserId &&
        m['status']?.toString() != 'cannot_attend');
  }).toList();

  final myInvites = activityFiltered
      .where((it) =>
          currentUserId.isNotEmpty &&
          it['host_user_id']?.toString() == currentUserId)
      .toList();

  final joinedInviteIds =
      joinedInvites.map((it) => it['id']?.toString()).toSet();

  final invitesForMe = activityFiltered.where((it) {
    final hostId = it['host_user_id']?.toString();
    if (currentUserId.isNotEmpty && hostId == currentUserId) return false;
    final id = it['id']?.toString();
    if (id != null && joinedInviteIds.contains(id)) return false;
    if (id != null && optimisticJoinedIds.contains(id)) return false;
    final groupId = it['group_id']?.toString();
    if (groupId != null && groupId.isNotEmpty) return false;
    return matchesAudience(it);
  }).toList();

  final groupInvites = activityFiltered.where((it) {
    final groupId = it['group_id']?.toString();
    if (groupId == null || groupId.isEmpty) return false;
    if (it['host_user_id']?.toString() == currentUserId) {
      return true;
    }
    return matchesAudience(it);
  }).toList();

  return InviteBuckets(
    joinedInvites: joinedInvites,
    myInvites: myInvites,
    invitesForMe: invitesForMe,
    groupInvites: groupInvites,
  );
}
