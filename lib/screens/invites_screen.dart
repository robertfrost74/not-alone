import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'create_invite_screen.dart';

class InvitesScreen extends StatefulWidget {
  final AppState appState;
  const InvitesScreen({super.key, required this.appState});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  bool _joining = false;
  bool _deleting = false;
  late Future<List<Map<String, dynamic>>> _invitesFuture;
  Timer? _clockTimer;

  String _activity = 'all'; // all|walk|coffee|workout|lunch|dinner
  String _mode = 'all'; // all|one_to_one|group

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  @override
  void initState() {
    super.initState();
    _invitesFuture = _loadInvites();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _reloadInvites() {
    setState(() => _invitesFuture = _loadInvites());
  }

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    final res = await Supabase.instance.client
        .from('invites')
        .select(
            'id, host_user_id, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, invite_members(status)')
        .match({'status': 'open'})
        .order('created_at', ascending: false)
        .limit(50);

    var invites = (res as List).cast<Map<String, dynamic>>();
    if (invites.isEmpty) return invites;

    if (_activity != 'all') {
      invites = invites.where((invite) {
        final activity = (invite['activity'] ?? '').toString();
        return _normalizeActivity(activity) == _normalizeActivity(_activity);
      }).toList();
    }

    if (_mode != 'all') {
      invites = invites.where((invite) {
        final mode = (invite['mode'] ?? '').toString();
        return _normalizeMode(mode) == _normalizeMode(_mode);
      }).toList();
    }

    for (final invite in invites) {
      final members = (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      invite['accepted_count'] =
          members.where((member) => member['status']?.toString() != 'cannot_attend').length;
    }
    return invites;
  }

  String _normalizeMode(String value) {
    if (value == '1to1') return 'one_to_one';
    return value;
  }

  String _normalizeActivity(String value) {
    if (value == 'fika') return 'coffee';
    return value;
  }

  Future<void> _joinInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invalid invite id', 'Ogiltigt invite-id'))),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final inserted = await Supabase.instance.client.from('invite_members').insert({
        'invite_id': inviteId,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'role': 'member',
      }).select('id').single();

      final inviteMemberId = inserted['id']?.toString();

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/meet',
        arguments: {
          'invite_id': inviteId,
          'invite_member_id': inviteMemberId,
          'created_at': invite['created_at'],
          'meeting_time': invite['meeting_time'],
          'place': invite['place'],
          'duration': invite['duration'],
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _deleteInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) return;

    final isConfirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(_t('Remove invite?', 'Ta bort inbjudan?')),
              content: Text(_t('This cannot be undone.', 'Detta kan inte ångras.')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_t('Cancel', 'Avbryt')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(_t('Remove', 'Ta bort')),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!isConfirmed) return;

    setState(() => _deleting = true);
    try {
      await Supabase.instance.client.from('invites').delete().match({'id': inviteId});
      if (!mounted) return;
      _reloadInvites();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _activityLabel(String a) {
    switch (a) {
      case 'walk':
        return isSv ? 'Promenad' : 'Walk';
      case 'coffee':
        return 'Fika';
      case 'workout':
        return isSv ? 'Träna' : 'Workout';
      case 'lunch':
        return isSv ? 'Luncha' : 'Lunch';
      case 'dinner':
        return isSv ? 'Middag' : 'Dinner';
      default:
        return a;
    }
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'one_to_one':
      case '1to1':
        return '1:1';
      case 'group':
        return isSv ? 'Grupp' : 'Group';
      default:
        return m;
    }
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return _t('Not set', 'Inte satt');
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    final y = parsed.year.toString().padLeft(4, '0');
    final mo = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    final h = parsed.hour.toString().padLeft(2, '0');
    final mi = parsed.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  double _timeLeftProgress(dynamic createdRaw, dynamic meetingRaw) {
    final createdAt = _parseDateTime(createdRaw);
    final meetingAt = _parseDateTime(meetingRaw);
    if (createdAt == null || meetingAt == null) return 0;
    final total = meetingAt.difference(createdAt).inSeconds;
    if (total <= 0) return 0;
    final remaining = meetingAt.difference(DateTime.now()).inSeconds;
    return (remaining / total).clamp(0.0, 1.0);
  }

  String _timeLeftLabel(dynamic meetingRaw) {
    final meetingAt = _parseDateTime(meetingRaw);
    if (meetingAt == null) return _t('No meeting time', 'Ingen mötestid');

    final diff = meetingAt.difference(DateTime.now());
    if (diff.inSeconds <= 0) return _t('Started', 'Startad');

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return isSv ? '$hours h $minutes min kvar' : '$hours h $minutes min left';
    }
    return isSv ? '${diff.inMinutes} min kvar' : '${diff.inMinutes} min left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSv ? 'Inbjudningar' : 'Invites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateInviteScreen(appState: widget.appState),
                ),
              );
              if (created == true && mounted) {
                _reloadInvites();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadInvites,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _activity,
                  decoration: InputDecoration(
                    labelText: isSv ? 'Aktivitet' : 'Activity',
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Alla / All')),
                    DropdownMenuItem(
                        value: 'walk', child: Text('Promenad / Walk')),
                    DropdownMenuItem(value: 'workout', child: Text('Träna / Workout')),
                    DropdownMenuItem(value: 'coffee', child: Text('Fika')),
                    DropdownMenuItem(value: 'lunch', child: Text('Luncha / Lunch')),
                    DropdownMenuItem(value: 'dinner', child: Text('Middag / Dinner')),
                  ],
                  onChanged: (v) {
                    _activity = v ?? 'all';
                    _reloadInvites();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: InputDecoration(
                    labelText: isSv ? 'Läge' : 'Mode',
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Alla / All')),
                    DropdownMenuItem(value: 'one_to_one', child: Text('1:1')),
                    DropdownMenuItem(
                        value: 'group', child: Text('Grupp / Group')),
                  ],
                  onChanged: (v) {
                    _mode = v ?? 'all';
                    _reloadInvites();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_joining) const LinearProgressIndicator(),
            if (_deleting) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _invitesFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(isSv
                          ? 'Inga öppna inbjudningar just nu'
                          : 'No open invites right now'),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      final place = (it['place'] ?? '').toString();
                      final meetingTimeLabel = _formatDateTime(it['meeting_time']);
                      final timeProgress = _timeLeftProgress(it['created_at'], it['meeting_time']);
                      final timeLeftLabel = _timeLeftLabel(it['meeting_time']);
                      final canDelete = it['host_user_id']?.toString() ==
                          Supabase.instance.client.auth.currentUser?.id;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_activityLabel(it['activity'])} • ${_modeLabel(it['mode'])} • ${it['duration']} min',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isSv
                                        ? '${it['accepted_count'] ?? 0} tackat ja'
                                        : '${it['accepted_count'] ?? 0} joined',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (canDelete) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                    onPressed: _deleting ? null : () => _deleteInvite(it),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    tooltip: _t('Remove invite', 'Ta bort inbjudan'),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSv
                                  ? 'Energi: ${it['energy']} • Prat: ${it['talk_level']}'
                                  : 'Energy: ${it['energy']} • Talk: ${it['talk_level']}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSv ? 'Tid: $meetingTimeLabel' : 'Time: $meetingTimeLabel',
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
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                            if (place.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(isSv ? 'Plats: $place' : 'Place: $place'),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: FilledButton(
                                onPressed: _joining
                                    ? null
                                    : () => _joinInvite(it),
                                child: Text(isSv ? 'Gå med' : 'Join'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
