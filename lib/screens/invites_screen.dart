import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'request_screen.dart';
import '../widgets/social_chrome.dart';

class InvitesScreen extends StatefulWidget {
  final AppState appState;
  const InvitesScreen({super.key, required this.appState});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  bool _joining = false;
  late Future<List<Map<String, dynamic>>> _invitesFuture;
  Timer? _clockTimer;
  Timer? _realtimeDebounceTimer;
  RealtimeChannel? _invitesChannel;

  String _activity = 'all'; // all|walk|coffee|workout|lunch|dinner

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  @override
  void initState() {
    super.initState();
    _invitesFuture = _loadInvites();
    _startRealtime();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _realtimeDebounceTimer?.cancel();
    final channel = _invitesChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _invitesChannel = null;
    }
    super.dispose();
  }

  void _reloadInvites() {
    if (!mounted) return;
    setState(() {
      _invitesFuture = _loadInvites();
    });
  }

  void _startRealtime() {
    _invitesChannel = Supabase.instance.client
        .channel('public:invites_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invites',
          callback: (_) => _scheduleRealtimeReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invite_members',
          callback: (_) => _scheduleRealtimeReload(),
        )
        .subscribe();
  }

  void _scheduleRealtimeReload() {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reloadInvites();
    });
  }

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    final res = await Supabase.instance.client
        .from('invites')
        .select(
            'id, host_user_id, max_participants, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, invite_members(status,user_id)')
        .match({'status': 'open'})
        .order('created_at', ascending: false)
        .limit(50);

    var invites = (res as List).cast<Map<String, dynamic>>();
    if (invites.isEmpty) return invites;

    Map<String, String> hostNamesById = {};
    try {
      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('id, username, full_name')
          .limit(2000);
      final profileRows = (profilesRes as List).cast<Map<String, dynamic>>();
      for (final row in profileRows) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final username = (row['username'] ?? '').toString().trim();
        final fullName = (row['full_name'] ?? '').toString().trim();
        final display = username.isNotEmpty
            ? username
            : (fullName.isNotEmpty ? fullName : '');
        if (display.isNotEmpty) hostNamesById[id] = display;
      }
    } catch (_) {
      // Keep invites page resilient if profiles table/policies differ.
    }

    for (final invite in invites) {
      final members =
          (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      invite['accepted_count'] = members
          .where((member) => member['status']?.toString() != 'cannot_attend')
          .length;
      final hostId = invite['host_user_id']?.toString() ?? '';
      final fallback = hostId.isEmpty
          ? _t('Unknown user', 'Okänd användare')
          : hostId.substring(0, hostId.length < 8 ? hostId.length : 8);
      invite['host_display_name'] = hostNamesById[hostId] ?? fallback;
    }
    return invites;
  }

  String _normalizeMode(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1to1' ||
        normalized == '1:1' ||
        normalized == 'one-to-one' ||
        normalized == 'one to one') {
      return 'one_to_one';
    }
    return normalized;
  }

  List<String> _acceptedUsers(Map<String, dynamic> invite) {
    final members =
        (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    return members
        .where((member) => member['status']?.toString() != 'cannot_attend')
        .map((member) => member['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> _showAcceptedUsersModal(Map<String, dynamic> invite) async {
    final users = _acceptedUsers(invite);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.white24),
          ),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          title: Text(_t('Joined users', 'Tackat ja')),
          content: users.isEmpty
              ? Text(_t('No one has joined yet.', 'Ingen har tackat ja ännu.'))
              : SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: users
                          .map(
                            (id) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                isSv
                                    ? 'Användare ${id.substring(0, id.length < 8 ? id.length : 8)}'
                                    : 'User ${id.substring(0, id.length < 8 ? id.length : 8)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('Close', 'Stäng')),
            ),
          ],
        );
      },
    );
  }

  String _normalizeActivity(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'fika' ||
        normalized == 'coffee' ||
        normalized == 'kaffe') {
      return 'coffee';
    }
    if (normalized == 'promenad' || normalized == 'walk') return 'walk';
    if (normalized == 'träna' ||
        normalized == 'trana' ||
        normalized == 'workout') {
      return 'workout';
    }
    if (normalized == 'lunch' || normalized == 'luncha') return 'lunch';
    if (normalized == 'middag' || normalized == 'dinner') return 'dinner';
    return normalized;
  }

  bool _matchesFilters(Map<String, dynamic> invite) {
    if (_activity != 'all') {
      final activity =
          _normalizeActivity((invite['activity'] ?? '').toString());
      if (activity != _normalizeActivity(_activity)) return false;
    }
    return true;
  }

  Future<void> _joinInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invalid invite id', 'Ogiltigt invite-id'))),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _joining = true;
    });
    try {
      final inserted = await Supabase.instance.client
          .from('invite_members')
          .insert({
            'invite_id': inviteId,
            'user_id': Supabase.instance.client.auth.currentUser?.id,
            'role': 'member',
          })
          .select('id')
          .single();

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
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  Future<void> _deleteInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) return;

    final isConfirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white24),
              ),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              contentTextStyle: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              title: Text(_t('Remove invite?', 'Ta bort inbjudan?')),
              content:
                  Text(_t('This cannot be undone.', 'Detta kan inte ångras.')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    _t('Cancel', 'Avbryt'),
                    style: const TextStyle(color: Colors.white70),
                  ),
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
    if (!mounted) return;

    try {
      // Clean up dependent rows first to avoid FK delete errors.
      await Supabase.instance.client
          .from('invite_members')
          .delete()
          .match({'invite_id': inviteId});
      await Supabase.instance.client
          .from('meetups')
          .delete()
          .match({'invite_id': inviteId});
      await Supabase.instance.client
          .from('invites')
          .delete()
          .match({'id': inviteId});
      if (!mounted) return;
      _reloadInvites();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
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

  String _countLabel(Map<String, dynamic> invite) {
    final mode = _normalizeMode((invite['mode'] ?? '').toString());
    final maxParticipants = (invite['max_participants'] as num?)?.toInt();
    final count = mode == 'one_to_one' ? 1 : maxParticipants;
    final value = count?.toString() ?? '-';
    return isSv ? 'Max antal: $value' : 'Max participants: $value';
  }

  String _joinedOfMaxLabel(Map<String, dynamic> invite) {
    final accepted = (invite['accepted_count'] as int?) ?? 0;
    final mode = _normalizeMode((invite['mode'] ?? '').toString());
    final rawMax = invite['max_participants'];
    final maxParticipants =
        rawMax is num ? rawMax.toInt() : int.tryParse(rawMax?.toString() ?? '');
    final maxValue = mode == 'one_to_one' ? 1 : (maxParticipants ?? 0);
    return '$accepted/$maxValue';
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

  String _inviteStatus(Map<String, dynamic> invite) {
    final meetingAt = _parseDateTime(invite['meeting_time']);
    final accepted = (invite['accepted_count'] as int?) ?? 0;
    final mode = _normalizeMode((invite['mode'] ?? '').toString());
    final rawMax = invite['max_participants'];
    final maxParticipants =
        rawMax is num ? rawMax.toInt() : int.tryParse(rawMax?.toString() ?? '');
    final now = DateTime.now();

    if (meetingAt != null) {
      final expiredAt = meetingAt.add(const Duration(minutes: 15));
      if (now.isAfter(expiredAt)) return 'expired';
      if (now.isAfter(meetingAt)) return 'started';
    }

    final isFull = mode == 'one_to_one'
        ? accepted >= 1
        : maxParticipants != null
            ? accepted >= maxParticipants
            : accepted >= 4;
    if (isFull) return 'full';
    return 'open';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'full':
        return isSv ? 'Full' : 'Full';
      case 'started':
        return isSv ? 'Startad' : 'Started';
      case 'expired':
        return isSv ? 'Utgången' : 'Expired';
      default:
        return isSv ? 'Öppen' : 'Open';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'full':
        return Colors.red.shade400;
      case 'started':
        return Colors.blue.shade100;
      case 'expired':
        return Colors.red.shade100;
      default:
        return Colors.green.shade100;
    }
  }

  bool _canJoinStatus(String status) => status == 'open';

  String _joinButtonLabel(String status) {
    switch (status) {
      case 'full':
        return isSv ? 'Full' : 'Full';
      case 'started':
        return isSv ? 'Startad' : 'Started';
      case 'expired':
        return isSv ? 'Utgången' : 'Expired';
      default:
        return isSv ? 'Gå med' : 'Join';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isSv ? 'Inbjudningar' : 'Invites'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestScreen(appState: widget.appState),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadInvites,
          )
        ],
      ),
      body: SocialBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: Column(
                children: [
                  Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isSv ? 'Aktivitet' : 'Activity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _activity,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF2DD4CF)),
                          ),
                        ),
                        dropdownColor: const Color(0xFF10201E),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              isSv ? 'Alla' : 'All',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'walk',
                            child: Text(
                              isSv ? 'Promenad' : 'Walk',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'workout',
                            child: Text(
                              isSv ? 'Träna' : 'Workout',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'coffee',
                            child: Text(
                              'Fika',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text(
                              isSv ? 'Luncha' : 'Lunch',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text(
                              isSv ? 'Middag' : 'Dinner',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _activity = v ?? 'all';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_joining) const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _invitesFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('Error: ${snap.error}'));
                        }

                        final allItems = snap.data ?? [];
                        final items = allItems.where(_matchesFilters).toList();

                        if (items.isEmpty) {
                          return Center(
                            child: Text(isSv
                                ? 'Inga öppna inbjudningar för filtret'
                                : 'No open invites for this filter'),
                          );
                        }

                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final it = items[i];
                            final place = (it['place'] ?? '').toString();
                            final meetingTimeLabel =
                                _formatDateTime(it['meeting_time']);
                            final timeProgress = _timeLeftProgress(
                                it['created_at'], it['meeting_time']);
                            final timeLeftLabel =
                                _timeLeftLabel(it['meeting_time']);
                            final status = _inviteStatus(it);
                            final canDelete = it['host_user_id']?.toString() ==
                                Supabase.instance.client.auth.currentUser?.id;

                            return Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _activityLabel(it['activity']),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              (it['host_display_name'] ?? '')
                                                  .toString(),
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          minimumSize: const Size(0, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showAcceptedUsersModal(it),
                                        child: Text(
                                          _joinedOfMaxLabel(it),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        constraints: const BoxConstraints(
                                            minHeight: 28),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: status == 'full'
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (canDelete) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          visualDensity: VisualDensity.standard,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                  width: 36, height: 36),
                                          onPressed: () => _deleteInvite(it),
                                          icon: const Icon(Icons.delete_outline,
                                              size: 22),
                                          tooltip: _t('Remove invite',
                                              'Ta bort inbjudan'),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _countLabel(it),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${it['duration']} min',
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
                                    isSv
                                        ? 'Tid: $meetingTimeLabel'
                                        : 'Time: $meetingTimeLabel',
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
                                  if (place.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      isSv
                                          ? 'Mötesplats: $place'
                                          : 'Meeting place: $place',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: FilledButton(
                                      onPressed:
                                          _joining || !_canJoinStatus(status)
                                              ? null
                                              : () => _joinInvite(it),
                                      child: Text(_joinButtonLabel(status)),
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
          ),
        ),
      ),
    );
  }
}
