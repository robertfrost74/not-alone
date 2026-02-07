import 'package:flutter/material.dart';

class InviteCard extends StatelessWidget {
  final String activityLabel;
  final String hostDisplayName;
  final String joinedLabel;
  final VoidCallback onShowJoined;
  final String statusLabel;
  final Color statusColor;
  final Color statusTextColor;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final String countLabel;
  final int durationMinutes;
  final String timeLine;
  final double timeProgress;
  final String timeLeftLabel;
  final String? placeLine;
  final String? groupName;
  final String? groupLabel;
  final String? genderTag;
  final bool joinEnabled;
  final String joinButtonLabel;
  final VoidCallback onJoin;
  final VoidCallback? onMore;

  const InviteCard({
    super.key,
    required this.activityLabel,
    required this.hostDisplayName,
    required this.joinedLabel,
    required this.onShowJoined,
    required this.statusLabel,
    required this.statusColor,
    required this.statusTextColor,
    required this.canEdit,
    required this.onEdit,
    this.onDelete,
    required this.countLabel,
    required this.durationMinutes,
    required this.timeLine,
    required this.timeProgress,
    required this.timeLeftLabel,
    required this.placeLine,
    required this.groupName,
    required this.groupLabel,
    required this.genderTag,
    required this.joinEnabled,
    required this.joinButtonLabel,
    required this.onJoin,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hostDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: onShowJoined,
                child: Text(
                  joinedLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minHeight: 28),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusTextColor,
                  ),
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: Icon(Icons.edit_outlined, size: 22),
                      ),
                    ),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(Icons.delete_outline, size: 22),
                        ),
                      ),
                  ],
                ),
              ],
              if (onMore != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onMore,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.more_vert, size: 22),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  countLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$durationMinutes min',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeLine,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: timeProgress,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeLeftLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (placeLine != null) ...[
            const SizedBox(height: 6),
            Text(
              placeLine!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (groupName != null && groupLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    groupName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  groupLabel!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (genderTag != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                genderTag!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: joinEnabled ? onJoin : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
              ),
              child: Text(joinButtonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
