List<Map<String, dynamic>> preserveInvitesWithCache({
  required List<Map<String, dynamic>> freshInvites,
  required List<Map<String, dynamic>> cachedInvites,
  required String currentUserId,
  required Set<String> optimisticJoinedInviteIds,
}) {
  bool isJoinedInvite(Map<String, dynamic> invite) {
    final id = invite['id']?.toString();
    if (id != null && optimisticJoinedInviteIds.contains(id)) {
      return true;
    }
    if (invite['joined_by_current_user'] == true) return true;
    if (currentUserId.isEmpty) return false;
    final members =
        (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    return members.any((member) =>
        member['user_id']?.toString() == currentUserId &&
        member['status']?.toString() != 'cannot_attend');
  }

  if (freshInvites.isEmpty && cachedInvites.isNotEmpty) {
    if (currentUserId.isNotEmpty) return cachedInvites;
    final joinedOnly =
        cachedInvites.where(isJoinedInvite).toList(growable: false);
    return joinedOnly;
  }
  if (cachedInvites.isEmpty) return freshInvites;

  final cachedById = <String, Map<String, dynamic>>{};
  for (final cached in cachedInvites) {
    final id = cached['id']?.toString();
    if (id == null || id.isEmpty) continue;
    cachedById[id] = cached;
  }

  // Preserve joined state for the same invite ids when backend temporarily drops it.
  for (final fresh in freshInvites) {
    final id = fresh['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final cached = cachedById[id];
    if (cached == null || !isJoinedInvite(cached)) continue;
    if (fresh['joined_by_current_user'] != true) {
      fresh['joined_by_current_user'] = true;
    }
    if (currentUserId.isEmpty) continue;
    final freshMembers =
        (fresh['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    final hasMember = freshMembers.any((member) =>
        member['user_id']?.toString() == currentUserId &&
        member['status']?.toString() != 'cannot_attend');
    if (!hasMember) {
      final cachedMembers =
          (cached['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      final cachedMember = cachedMembers.firstWhere(
        (member) =>
            member['user_id']?.toString() == currentUserId &&
            member['status']?.toString() != 'cannot_attend',
        orElse: () => const {},
      );
      if (cachedMember.isNotEmpty) {
        fresh['invite_members'] = <Map<String, dynamic>>[
          ...freshMembers,
          Map<String, dynamic>.from(cachedMember),
        ];
      }
    }
  }

  final freshIds = freshInvites
      .map((invite) => invite['id']?.toString())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();

  final preservedJoined = <Map<String, dynamic>>[];
  for (final cached in cachedInvites) {
    final id = cached['id']?.toString();
    if (id == null || id.isEmpty || freshIds.contains(id)) continue;

    // For the same authenticated user, preserve missing cached items as well
    // to avoid destructive drops from transient/partial backend responses.
    if (currentUserId.isNotEmpty || isJoinedInvite(cached)) {
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
