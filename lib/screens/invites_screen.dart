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

  String _activity = 'all'; // all|walk|coffee|workout|lunch|dinner
  String _mode = 'all'; // all|one_to_one|group

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    final where = <String, Object>{
      'status': 'open',
    };

    if (_activity != 'all') where['activity'] = _activity as Object;
    if (_mode != 'all') where['mode'] = _mode as Object;

    final res = await Supabase.instance.client
        .from('invites')
        .select(
            'id, host_user_id, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, invite_members(status)')
        .match(where)
        .order('created_at', ascending: false)
        .limit(50);

    final invites = (res as List).cast<Map<String, dynamic>>();
    if (invites.isEmpty) return invites;
    for (final invite in invites) {
      final members = (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      invite['accepted_count'] =
          members.where((member) => member['status']?.toString() != 'cannot_attend').length;
    }
    return invites;
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
      setState(() {});
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
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
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
                  onChanged: (v) => setState(() => _activity = v ?? 'all'),
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
                  onChanged: (v) => setState(() => _mode = v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_joining) const LinearProgressIndicator(),
            if (_deleting) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadInvites(),
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
