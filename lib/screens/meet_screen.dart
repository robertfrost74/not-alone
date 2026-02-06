import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../widgets/social_chrome.dart';

class MeetScreen extends StatefulWidget {
  final AppState appState;

  /// Default meet duration after you press “I’m here”.
  final int minutes;
  final String? inviteId;
  final String? inviteMemberId;
  final DateTime? initialMeetingTime;
  final DateTime? initialCreatedAt;
  final String? initialPlace;

  const MeetScreen({
    super.key,
    required this.appState,
    this.minutes = 20,
    this.inviteId,
    this.inviteMemberId,
    this.initialMeetingTime,
    this.initialCreatedAt,
    this.initialPlace,
  });

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  Timer? _timer;
  Timer? _meetingTimer;

  // Pre-meet info
  DateTime? _meetingTime; // when you plan to meet
  String _placeName = ''; // simple MVP: free text

  // Meet-mode state
  bool _started = false; // becomes true after “I’m here” or “Start now”
  int _remainingSeconds = 0;
  int _meetingCountdownSeconds = 0;
  double _meetingProgress = 0;
  String? _meetupId;

  String _t(String en, String sv) =>
      widget.appState.locale.languageCode == 'sv' ? sv : en;
  bool get _hasPlace => _placeName.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // MVP defaults:
    _meetingTime = widget.initialMeetingTime ??
        DateTime.now().add(const Duration(minutes: 10));
    _placeName = (widget.initialPlace ?? '').trim();
    _remainingSeconds = widget.minutes * 60;
    _startMeetingCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _meetingTimer?.cancel();
    super.dispose();
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    // simple, locale-light formatting
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  String _hmmss(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    if (h == 0) return '$m:${s.toString().padLeft(2, '0')}';
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startMeetingCountdown() {
    final createdAt = widget.initialCreatedAt;
    final meetingTime = _meetingTime;
    if (meetingTime == null || createdAt == null) return;

    void tick() {
      if (!mounted) return;
      final now = DateTime.now();
      final totalWindow = meetingTime.difference(createdAt).inSeconds;
      final elapsed = now.difference(createdAt).inSeconds;
      final progress =
          totalWindow <= 0 ? 1.0 : (elapsed / totalWindow).clamp(0.0, 1.0);
      setState(() {
        _meetingCountdownSeconds =
            meetingTime.difference(now).inSeconds.clamp(0, 999999);
        _meetingProgress = progress;
      });
    }

    _meetingTimer?.cancel();
    tick();
    _meetingTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _pickMeetingTime() async {
    final now = DateTime.now();
    final isSv = widget.appState.locale.languageCode == 'sv';

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _meetingTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
      helpText: isSv ? 'Välj datum' : 'Pick a date',
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingTime ?? now),
      helpText: isSv ? 'Välj tid' : 'Pick a time',
    );
    if (pickedTime == null) return;
    if (!mounted) return;

    setState(() {
      _meetingTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
    _startMeetingCountdown();
  }

  Future<void> _editPlaceName() async {
    final controller = TextEditingController(text: _placeName);
    final isSv = widget.appState.locale.languageCode == 'sv';

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SocialSheetContent(
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isSv ? 'Mötesplats' : 'Meeting place',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText:
                          isSv ? 'Skriv in mötesplats' : 'Enter meeting place',
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: Text(isSv ? 'Spara' : 'Save'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    if (result.isEmpty) return;

    setState(() => _placeName = result);
  }

  Future<void> _upsertMeetupStarted() async {
    final inviteId = widget.inviteId;
    final inviteMemberId = widget.inviteMemberId;
    if (inviteId == null || inviteMemberId == null) return;

    try {
      if (_meetupId == null) {
        final existing = await Supabase.instance.client
            .from('meetups')
            .select('id, extended_minutes')
            .match({'invite_member_id': inviteMemberId}).limit(1);

        final rows = (existing as List).cast<Map<String, dynamic>>();
        if (rows.isNotEmpty) {
          _meetupId = rows.first['id']?.toString();
        }
      }

      if (_meetupId == null) {
        final inserted = await Supabase.instance.client
            .from('meetups')
            .insert({
              'invite_id': inviteId,
              'invite_member_id': inviteMemberId,
              'user_id': Supabase.instance.client.auth.currentUser?.id,
              'started_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        _meetupId = inserted['id']?.toString();
      } else {
        final meetupId = _meetupId;
        if (meetupId == null) return;
        await Supabase.instance.client.from('meetups').update({
          'started_at': DateTime.now().toIso8601String(),
        }).match({'id': meetupId});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_t('Sync failed', 'Synk misslyckades')}: $e')),
      );
    }
  }

  Future<void> _persistFinish() async {
    final meetupId = _meetupId;
    if (meetupId == null) return;
    try {
      await Supabase.instance.client.from('meetups').update({
        'ended_at': DateTime.now().toIso8601String(),
      }).match({'id': meetupId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_t('Sync failed', 'Synk misslyckades')}: $e')),
      );
    }
  }

  Future<void> _persistCannotCome() async {
    final inviteMemberId = widget.inviteMemberId;
    if (inviteMemberId == null || inviteMemberId.isEmpty) return;

    try {
      await Supabase.instance.client.from('invite_members').update({
        'status': 'cannot_attend',
        'cannot_come_at': DateTime.now().toIso8601String(),
      }).match({'id': inviteMemberId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_t('Sync failed', 'Synk misslyckades')}: $e')),
      );
    }
  }

  Future<void> _startMeetMode() async {
    if (_started) return;
    if (!_hasPlace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _t('Enter meeting place first', 'Skriv in mötesplats först'))),
      );
      return;
    }
    _meetingTimer?.cancel();

    setState(() {
      _started = true;
      _remainingSeconds = widget.minutes * 60;
    });
    await _upsertMeetupStarted();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });

      if (_remainingSeconds == 0) {
        _timer?.cancel();
        _persistFinish();
      }
    });
  }

  Widget _infoRow(String label, String value, VoidCallback onEdit) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.edit, size: 18, color: Colors.white60),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final meetingTimeText = _meetingTime == null
        ? _t('Not set', 'Inte satt')
        : _formatDateTime(_meetingTime!);
    final placeText = _placeName.isEmpty
        ? _t('Enter meeting place', 'Skriv in mötesplats')
        : _placeName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isSv ? 'Möte' : 'Meet'),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isSv ? 'Meet mode' : 'Meet mode',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    isSv ? 'Tid' : 'Time',
                    meetingTimeText,
                    _pickMeetingTime,
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    isSv ? 'Mötesplats' : 'Meeting place',
                    placeText,
                    _editPlaceName,
                  ),
                  const SizedBox(height: 18),
                  if (!_started) ...[
                    if (widget.initialCreatedAt != null &&
                        _meetingTime != null) ...[
                      Text(
                        isSv ? 'Nedräkning till mötet' : 'Countdown to meetup',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hmmss(_meetingCountdownSeconds),
                        style: const TextStyle(
                            fontSize: 44, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _meetingProgress,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(_meetingProgress * 100).round()}%',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      isSv
                          ? 'När ni ses: tryck “Jag är här” för att starta timern.'
                          : 'When you meet: tap “I’m here” to start the timer.',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: !_hasPlace
                            ? null
                            : () async {
                                await _startMeetMode();
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                      content: Text(isSv
                                          ? 'Markerad: Jag är här ✅'
                                          : 'Marked: I’m here ✅')),
                                );
                              },
                        child: Text(isSv ? 'Jag är här' : 'I’m here'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed:
                          !_hasPlace ? null : () async => _startMeetMode(),
                      child: Text(isSv ? 'Starta nu' : 'Start now'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        _timer?.cancel();
                        await _persistCannotCome();
                        await _persistFinish();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                              content: Text(isSv
                                  ? 'Meddelande skickat: Kan inte komma'
                                  : 'Message sent: Cannot come')),
                        );
                        Navigator.pop(this.context);
                      },
                      child: Text(isSv ? 'Kan inte komma' : 'Cannot come'),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      _mmss(_remainingSeconds),
                      style: const TextStyle(
                          fontSize: 64, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isSv
                          ? 'Låg press. Små steg.'
                          : 'Low pressure. Small steps.',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              _timer?.cancel();
                              await _persistFinish();
                              if (!mounted) return;
                              Navigator.pop(this.context);
                            },
                            child: Text(isSv ? 'Avsluta' : 'Finish'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
