import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../widgets/social_chrome.dart';

class MatchScreen extends StatefulWidget {
  final AppState appState;
  final String selectedActivity;
  final int selectedDuration;
  final String selectedMode;
  final String selectedEnergy;
  final int? selectedMaxParticipants;

  const MatchScreen({
    super.key,
    required this.appState,
    required this.selectedActivity,
    required this.selectedDuration,
    required this.selectedMode,
    required this.selectedEnergy,
    required this.selectedMaxParticipants,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool _loading = false;
  DateTime? _inviteMeetingTime;
  late TextEditingController _invitePlaceController;

  @override
  void initState() {
    super.initState();
    _invitePlaceController = TextEditingController();
  }

  @override
  void dispose() {
    _invitePlaceController.dispose();
    super.dispose();
  }

  String _t(String en, String sv) =>
      widget.appState.locale.languageCode == 'sv' ? sv : en;

  String _activityLabel(String activity) {
    switch (activity) {
      case 'walk':
        return _t('Walk', 'Promenad');
      case 'coffee':
        return _t('Fika', 'Fika');
      case 'workout':
        return _t('Workout', 'Träna');
      case 'lunch':
        return _t('Lunch', 'Lunch');
      case 'dinner':
        return _t('Dinner', 'Middag');
      default:
        return activity;
    }
  }

  String _modeLabel(String mode) {
    if (mode == 'group') return _t('Group', 'Grupp');
    return _t('1:1', '1:1');
  }

  Future<bool> _showInviteConfirmModal({
    required String activity,
    required int duration,
    required DateTime meetingTime,
    required String place,
  }) async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.white24),
          ),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          title: Text(isSv ? 'Godkänn inbjudan' : 'Confirm invite'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${isSv ? 'Aktivitet' : 'Activity'}: ${_activityLabel(activity)}'),
              const SizedBox(height: 6),
              Text(
                  '${isSv ? 'Tidpunkt' : 'Time'}: ${_formatDateTime(meetingTime)}'),
              const SizedBox(height: 6),
              Text('${isSv ? 'Mötesplats' : 'Meeting place'}: $place'),
              const SizedBox(height: 6),
              Text(
                  '${isSv ? 'Längd' : 'Duration'}: $duration ${isSv ? 'min' : 'min'}'),
              const SizedBox(height: 6),
              Text(
                  '${isSv ? 'Antal' : 'Mode'}: ${_modeLabel(widget.selectedMode)}'),
              if (widget.selectedMode == 'group' &&
                  widget.selectedMaxParticipants != null) ...[
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Max antal' : 'Max participants'}: ${widget.selectedMaxParticipants}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                isSv ? 'Avbryt' : 'Cancel',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isSv ? 'Godkänn' : 'Approve'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  _MatchCardData _cardForSelectedActivity() {
    final duration = widget.selectedDuration;
    switch (widget.selectedActivity) {
      case 'walk':
        return _MatchCardData(
          activity: 'walk',
          duration: duration,
        );
      case 'coffee':
        return _MatchCardData(
          activity: 'coffee',
          duration: duration,
        );
      case 'workout':
        return _MatchCardData(
          activity: 'workout',
          duration: duration,
        );
      case 'lunch':
        return _MatchCardData(
          activity: 'lunch',
          duration: duration,
        );
      case 'dinner':
        return _MatchCardData(
          activity: 'dinner',
          duration: duration,
        );
      default:
        return _MatchCardData(
          activity: widget.selectedActivity,
          duration: duration,
        );
    }
  }

  Future<String?> _createOpenInvite({
    required String activity,
    required int duration,
    required DateTime meetingTime,
    required String place,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final data = await Supabase.instance.client
        .from('invites')
        .insert({
          'host_user_id': userId,
          'activity': activity,
          'mode': widget.selectedMode,
          'max_participants': widget.selectedMode == 'group'
              ? widget.selectedMaxParticipants
              : null,
          'energy': widget.selectedEnergy,
          'talk_level': 'low',
          'duration': duration,
          'meeting_time': meetingTime.toIso8601String(),
          'place': place,
          'status': 'open',
        })
        .select('id')
        .single();

    return data['id']?.toString();
  }

  Future<void> _onInvitePressed({
    required String activity,
    required int duration,
  }) async {
    final meetingTime = _inviteMeetingTime;
    if (meetingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_t('Pick meeting time first', 'Välj tidpunkt först'))),
      );
      return;
    }

    final place = _invitePlaceController.text.trim();
    if (place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _t('Enter meeting place first', 'Skriv in mötesplats först'))),
      );
      return;
    }

    try {
      final approved = await _showInviteConfirmModal(
        activity: activity,
        duration: duration,
        meetingTime: meetingTime,
        place: place,
      );
      if (!approved || !mounted) return;

      setState(() => _loading = true);
      await _createOpenInvite(
        activity: activity,
        duration: duration,
        meetingTime: meetingTime,
        place: place,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/hub', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Fel:', 'Fel:')} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  Future<void> _pickInviteMeetingTime() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final now = DateTime.now();
    final initialMeetingTime =
        _inviteMeetingTime ?? now.add(const Duration(minutes: 10));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialMeetingTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: isSv ? 'Välj datum' : 'Pick a date',
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialMeetingTime),
      helpText: isSv ? 'Välj tid' : 'Pick a time',
    );
    if (pickedTime == null) return;

    setState(() {
      _inviteMeetingTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = [_cardForSelectedActivity()];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Create invite', 'Skapa inbjudan')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SocialBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final m = matches[index];
                        return _MatchCard(
                          timeLabel: _inviteMeetingTime == null
                              ? _t('Pick meeting time', 'Välj tidpunkt')
                              : _formatDateTime(_inviteMeetingTime!),
                          placeFieldLabel: _t('Meeting place', 'Mötesplats'),
                          placeController: _invitePlaceController,
                          placeHint:
                              _t('Enter meeting place', 'Skriv in mötesplats'),
                          onEditTime: _pickInviteMeetingTime,
                          buttonText: _t('Send invite', 'Skicka inbjudan'),
                          onInvite: _loading
                              ? null
                              : () => _onInvitePressed(
                                    activity: m.activity,
                                    duration: m.duration,
                                  ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchCardData {
  final String activity;
  final int duration;

  const _MatchCardData({
    required this.activity,
    required this.duration,
  });
}

class _MatchCard extends StatelessWidget {
  final String timeLabel;
  final String placeFieldLabel;
  final TextEditingController placeController;
  final String placeHint;
  final VoidCallback onEditTime;
  final String buttonText;
  final VoidCallback? onInvite;

  const _MatchCard({
    required this.timeLabel,
    required this.placeFieldLabel,
    required this.placeController,
    required this.placeHint,
    required this.onEditTime,
    required this.buttonText,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoEditRow(
            label: 'Time',
            value: timeLabel,
            onTap: onEditTime,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: placeController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: placeFieldLabel,
              hintText: placeHint,
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onInvite,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoEditRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InfoEditRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 18, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}
