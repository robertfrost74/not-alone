class JoinUiState {
  final bool enabled;
  final String label;

  const JoinUiState({
    required this.enabled,
    required this.label,
  });
}

JoinUiState computeJoinUiState({
  required String? inviteId,
  required String? joiningInviteId,
  required bool canJoin,
  required bool isJoinCooldownActive,
  required bool isSv,
  required String defaultLabel,
}) {
  final isJoining =
      inviteId != null && inviteId.isNotEmpty && inviteId == joiningInviteId;
  if (isJoining) {
    return JoinUiState(
      enabled: false,
      label: isSv ? 'Går med...' : 'Joining...',
    );
  }
  return JoinUiState(
    enabled: canJoin && !isJoinCooldownActive,
    label: defaultLabel,
  );
}
