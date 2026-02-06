enum InviteStatus {
  open,
  full,
  started,
  expired,
}

InviteStatus computeInviteStatus({
  required DateTime? meetingAt,
  required int accepted,
  required String mode,
  required int? maxParticipants,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();

  if (meetingAt != null) {
    final expiredAt = meetingAt.add(const Duration(minutes: 15));
    if (current.isAfter(expiredAt)) return InviteStatus.expired;
    if (current.isAfter(meetingAt)) return InviteStatus.started;
  }

  final isFull = mode == 'one_to_one'
      ? accepted >= 1
      : maxParticipants != null
          ? accepted >= maxParticipants
          : accepted >= 4;
  if (isFull) return InviteStatus.full;
  return InviteStatus.open;
}
