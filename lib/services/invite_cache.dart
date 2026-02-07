List<Map<String, dynamic>> preserveInvitesWithCache({
  required List<Map<String, dynamic>> freshInvites,
  required List<Map<String, dynamic>> cachedInvites,
  required String currentUserId,
  required Set<String> optimisticJoinedInviteIds,
}) {
  if (freshInvites.isEmpty && cachedInvites.isNotEmpty) {
    return cachedInvites;
  }
  if (cachedInvites.isEmpty) return freshInvites;

  final freshIds = freshInvites
      .map((invite) => invite['id']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();

  final preservedJoined = <Map<String, dynamic>>[];
  for (final cached in cachedInvites) {
    final id = cached['id']?.toString();
    if (id == null || id.isEmpty || freshIds.contains(id)) continue;

    if (currentUserId.isEmpty) {
      // Avoid destructive drops while auth/current user id is transiently unavailable.
      preservedJoined.add(cached);
      continue;
    }

    final members =
        (cached['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    final joinedFlag = cached['joined_by_current_user'] == true;
    final joinedByCurrentUser = currentUserId.isNotEmpty &&
        members.any((member) =>
            member['user_id']?.toString() == currentUserId &&
            member['status']?.toString() != 'cannot_attend');
    final optimisticJoined = optimisticJoinedInviteIds.contains(id);

    if (joinedFlag || joinedByCurrentUser || optimisticJoined) {
      preservedJoined.add(cached);
    }
  }

  if (preservedJoined.isEmpty) return freshInvites;
  return <Map<String, dynamic>>[...freshInvites, ...preservedJoined];
}

List<Map<String, dynamic>> mergeInvitesById({
  required List<Map<String, dynamic>> baseInvites,
  required List<Map<String, dynamic>> extraInvites,
}) {
  if (extraInvites.isEmpty) return baseInvites;
  final merged = <String, Map<String, dynamic>>{};
  for (final invite in baseInvites) {
    final id = invite['id']?.toString();
    if (id == null || id.isEmpty) continue;
    merged[id] = invite;
  }
  for (final invite in extraInvites) {
    final id = invite['id']?.toString();
    if (id == null || id.isEmpty) continue;
    merged[id] = invite;
  }
  return merged.values.toList(growable: false);
}
