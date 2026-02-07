int computeAcceptedCount({
  required List<Map<String, dynamic>> members,
  required String? inviteId,
  required Set<String> optimisticJoinedIds,
  required String? currentUserId,
}) {
  final acceptedCount = members
      .where((member) => member['status']?.toString() != 'cannot_attend')
      .length;
  if (inviteId == null ||
      inviteId.isEmpty ||
      currentUserId == null ||
      currentUserId.isEmpty) {
    return acceptedCount;
  }
  if (!optimisticJoinedIds.contains(inviteId)) {
    return acceptedCount;
  }
  final alreadyJoined = members.any((m) =>
      m['user_id']?.toString() == currentUserId &&
      m['status']?.toString() != 'cannot_attend');
  return alreadyJoined ? acceptedCount : acceptedCount + 1;
}
