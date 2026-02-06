import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'groups_screen.dart';
import 'request_screen.dart';
import 'welcome_screen.dart';
import '../widgets/social_chrome.dart';

class InvitesScreen extends StatefulWidget {
  final AppState appState;
  const InvitesScreen({super.key, required this.appState});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  bool _joining = false;
  bool _menuLoading = false;
  late Future<List<Map<String, dynamic>>> _invitesFuture;
  Timer? _clockTimer;
  Timer? _realtimeDebounceTimer;
  RealtimeChannel? _invitesChannel;

  String _activity = 'all'; // all|walk|coffee|workout|lunch|dinner

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  int? get _currentUserAge {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (metadata == null) return null;
    final raw = metadata['age'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _normalizeGender(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'man' || v == 'män' || v == 'male') return 'male';
    if (v == 'kvinna' || v == 'kvinnor' || v == 'female') return 'female';
    if (v == 'alla' || v == 'all') return 'all';
    return v;
  }

  String? get _currentUserGender {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    if (metadata == null) return null;
    final raw = metadata['gender']?.toString() ?? '';
    final normalized = _normalizeGender(raw);
    if (normalized != 'male' && normalized != 'female') return null;
    return normalized;
  }

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

  Future<void> _signOut() async {
    setState(() => _menuLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(appState: widget.appState),
        ),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _menuLoading = false);
    }
  }

  Future<void> _onMenuSelected(String value) async {
    if (value == 'profile') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(appState: widget.appState),
        ),
      );
      return;
    }
    if (value == 'groups') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupsScreen(appState: widget.appState),
        ),
      );
      return;
    }
    if (value == 'messages') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatsScreen(appState: widget.appState),
        ),
      );
      return;
    }
    if (value == 'invites') {
      if (!mounted) return;
      return;
    }
    if (value == 'logout') {
      await _signOut();
    }
  }

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    final res = await Supabase.instance.client
        .from('invites')
        .select(
            'id, host_user_id, max_participants, target_gender, age_min, age_max, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, group_id, groups(name), invite_members(status,user_id)')
        .match({'status': 'open'})
        .order('created_at', ascending: false)
        .limit(50);

    var invites = (res as List).cast<Map<String, dynamic>>();
    if (invites.isEmpty) return invites;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      final groupRows = await Supabase.instance.client
          .from('group_members')
          .select('group_id')
          .match({'user_id': currentUserId});
      final memberGroupIds = <String>{};
      if (groupRows is List) {
        for (final row in groupRows.whereType<Map<String, dynamic>>()) {
          final id = row['group_id']?.toString();
          if (id != null && id.isNotEmpty) memberGroupIds.add(id);
        }
      }
      invites = invites.where((invite) {
        final groupId = invite['group_id']?.toString();
        if (groupId == null || groupId.isEmpty) return true;
        return memberGroupIds.contains(groupId);
      }).toList();
    }

    Map<String, String> hostNamesById = {};
    try {
      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('id, username')
          .limit(2000);
      final profileRows = (profilesRes as List).cast<Map<String, dynamic>>();
      for (final row in profileRows) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final username = (row['username'] ?? '').toString().trim();
        final display = username.isNotEmpty ? username : '';
        if (display.isNotEmpty) hostNamesById[id] = display;
      }
    } catch (_) {
      // Keep invites page resilient if profiles table/policies differ.
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUsername =
        (currentUser?.userMetadata?['username'] ?? '').toString().trim();
    final currentDisplay = currentUsername.isNotEmpty ? currentUsername : '';

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
      if (currentDisplay.isNotEmpty && hostId == currentUserId) {
        invite['host_display_name'] = currentDisplay;
      } else {
        invite['host_display_name'] = hostNamesById[hostId] ?? fallback;
      }
      final group = invite['groups'] as Map<String, dynamic>?;
      invite['group_name'] = (group?['name'] ?? '').toString();
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
        return SocialDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          title: Text(_t('Joined users', 'Tackat ja')),
          content: users.isEmpty
              ? Text(_t('No one has joined yet.', 'Ingen har tackat ja ännu.'))
              : SingleChildScrollView(
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

    final age = _currentUserAge;
    if (age != null) {
      final minRaw = invite['age_min'];
      final maxRaw = invite['age_max'];
      final ageMin =
          minRaw is num ? minRaw.toInt() : int.tryParse(minRaw?.toString() ?? '');
      final ageMax =
          maxRaw is num ? maxRaw.toInt() : int.tryParse(maxRaw?.toString() ?? '');
      if (ageMin != null && age < ageMin) return false;
      if (ageMax != null && age > ageMax) return false;
    }

    final targetGender =
        _normalizeGender((invite['target_gender'] ?? 'all').toString());
    if (targetGender == 'male' || targetGender == 'female') {
      final viewerGender = _currentUserGender;
      if (viewerGender == null) return false;
      if (viewerGender != targetGender) return false;
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

  Future<void> _editInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    final hostId = invite['host_user_id']?.toString();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (inviteId == null || inviteId.isEmpty || userId == null || hostId != userId) {
      return;
    }

    String activity = _normalizeActivity((invite['activity'] ?? 'walk').toString());
    int duration = (invite['duration'] as num?)?.toInt() ??
        int.tryParse(invite['duration']?.toString() ?? '') ??
        20;
    int maxParticipants = (invite['max_participants'] as num?)?.toInt() ??
        int.tryParse(invite['max_participants']?.toString() ?? '') ??
        2;
    final mode = _normalizeMode((invite['mode'] ?? '').toString());
    final placeController = TextEditingController(text: (invite['place'] ?? '').toString());
    DateTime meetingTime =
        _parseDateTime(invite['meeting_time']) ?? DateTime.now().add(const Duration(minutes: 10));
    RangeValues ageRange = RangeValues(
      ((invite['age_min'] as num?)?.toDouble() ??
              double.tryParse(invite['age_min']?.toString() ?? '') ??
              16)
          .clamp(16, 120),
      ((invite['age_max'] as num?)?.toDouble() ??
              double.tryParse(invite['age_max']?.toString() ?? '') ??
              120)
          .clamp(16, 120),
    );
    if (ageRange.start > ageRange.end) {
      ageRange = RangeValues(ageRange.end, ageRange.start);
    }
    String targetGender =
        _normalizeGender((invite['target_gender'] ?? 'all').toString());
    if (targetGender != 'male' && targetGender != 'female') targetGender = 'all';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1A1A),
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final activityItems = [
              DropdownMenuItem(
                  value: 'walk',
                  child: Text(isSv ? 'Promenad' : 'Walk')),
              const DropdownMenuItem(value: 'coffee', child: Text('Fika')),
              DropdownMenuItem(
                  value: 'workout',
                  child: Text(isSv ? 'Träna' : 'Workout')),
              DropdownMenuItem(
                  value: 'lunch',
                  child: Text(isSv ? 'Luncha' : 'Lunch')),
              DropdownMenuItem(
                  value: 'dinner',
                  child: Text(isSv ? 'Middag' : 'Dinner')),
            ];
            final activityValues =
                activityItems.map((e) => e.value).whereType<String>();
            if (!activityValues.contains(activity)) {
              activityItems.add(
                DropdownMenuItem(
                  value: activity,
                  child: Text(_activityLabel(activity)),
                ),
              );
            }

            Future<void> pickMeetingTime() async {
              final date = await showDatePicker(
                context: sheetContext,
                initialDate: meetingTime,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                helpText: isSv ? 'Välj datum' : 'Pick date',
              );
              if (date == null) return;
              final time = await showTimePicker(
                context: sheetContext,
                initialTime: TimeOfDay.fromDateTime(meetingTime),
                helpText: isSv ? 'Välj tid' : 'Pick time',
              );
              if (time == null) return;
              setSheetState(() {
                meetingTime = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute);
              });
            }

            return SafeArea(
              child: SocialSheetContent(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t('Edit invite', 'Redigera inbjudan'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('Activity', 'Aktivitet'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                        initialValue: activity,
                        dropdownColor: const Color(0xFF10201E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: activityItems,
                        onChanged: (v) =>
                            setSheetState(() => activity = v ?? activity),
                      ),
                        const SizedBox(height: 12),
                        Text(
                          _t('Meeting place', 'Mötesplats'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: placeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: _t('Enter place', 'Ange plats'),
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_t('Time', 'Tid')}: ${_formatDateTime(meetingTime.toIso8601String())}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: pickMeetingTime,
                            child: Text(_t('Change time', 'Ändra tid')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_t('Duration', 'Längd')}: $duration min',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        Slider(
                          min: 10,
                          max: 120,
                          divisions: 110,
                          value: duration.toDouble().clamp(10, 120),
                          label: '$duration',
                          onChanged: (v) =>
                              setSheetState(() => duration = v.round()),
                        ),
                        if (mode != 'one_to_one') ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_t('Max participants', 'Max antal')}: $maxParticipants',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          Slider(
                            min: 2,
                            max: 10,
                            divisions: 8,
                            value: maxParticipants.toDouble().clamp(2, 10),
                            label: '$maxParticipants',
                            onChanged: (v) =>
                                setSheetState(() => maxParticipants = v.round()),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${_t('Age range', 'Ålders spann')}: ${ageRange.start.round()}-${ageRange.end.round()}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        RangeSlider(
                          min: 16,
                          max: 120,
                          divisions: 104,
                          values: ageRange,
                          labels: RangeLabels(
                            '${ageRange.start.round()}',
                            '${ageRange.end.round()}',
                          ),
                          onChanged: (v) => setSheetState(() => ageRange = v),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t('Show invite for', 'Visa inbjudan för'),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                          SocialChoiceChip(
                            label: _t('All', 'Alla'),
                            selected: targetGender == 'all',
                            onSelected: (_) =>
                                setSheetState(() => targetGender = 'all'),
                          ),
                          SocialChoiceChip(
                            label: _t('Men', 'Män'),
                            selected: targetGender == 'male',
                            onSelected: (_) =>
                                setSheetState(() => targetGender = 'male'),
                          ),
                          SocialChoiceChip(
                            label: _t('Women', 'Kvinnor'),
                            selected: targetGender == 'female',
                            onSelected: (_) =>
                                setSheetState(() => targetGender = 'female'),
                          ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext, true),
                            child: Text(_t('Save changes', 'Spara ändringar')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final updatedPlace = placeController.text.trim();
    placeController.dispose();
    if (saved != true) return;

    try {
      await Supabase.instance.client.from('invites').update({
        'activity': activity,
        'place': updatedPlace,
        'duration': duration,
        'meeting_time': meetingTime.toIso8601String(),
        'max_participants': mode == 'one_to_one' ? null : maxParticipants,
        'age_min': ageRange.start.round(),
        'age_max': ageRange.end.round(),
        'target_gender': targetGender,
      }).match({
        'id': inviteId,
        'host_user_id': userId,
      });

      if (!mounted) return;
      _reloadInvites();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invite updated', 'Inbjudan uppdaterad'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    }
  }

  Future<void> _deleteInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) return;

    final isConfirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return SocialDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
              title: Text(_t('Remove invite?', 'Ta bort inbjudan?')),
              content:
                  Text(_t('This cannot be undone.', 'Detta kan inte ångras.')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_t('Cancel', 'Avbryt')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(isSv ? 'Inbjudningar' : 'Invites'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/invites', (route) => false);
            },
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: const Color(0xFF2DD4CF),
            tabs: [
              Tab(text: isSv ? 'Aktuella' : 'Current'),
              Tab(text: isSv ? 'Mina' : 'Mine'),
              Tab(text: isSv ? 'Tackat ja' : 'Joined'),
              Tab(text: isSv ? 'Grupper' : 'Groups'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              enabled: !_menuLoading,
              icon: const Icon(Icons.menu),
              color: const Color(0xFF10201E),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white24),
              ),
              onSelected: _onMenuSelected,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Profile', 'Profil'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'groups',
                  child: Row(
                    children: [
                      const Icon(Icons.groups_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Groups', 'Grupper'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'messages',
                  child: Row(
                    children: [
                      const Icon(Icons.markunread_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Chats', 'Chattar'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'invites',
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Invites', 'Inbjudningar'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Sign out', 'Logga ut'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SocialBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SocialPanel(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RequestScreen(appState: widget.appState),
                          ),
                        );
                      },
                      child: Text(_t('Create invite', 'Skapa inbjudan')),
                    ),
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
                          final currentUserId =
                              Supabase.instance.client.auth.currentUser?.id ?? '';
                          final filtered =
                              allItems.where(_matchesFilters).toList();
                          final hasAnyInvites = allItems.isNotEmpty;

                          final joinedInvites = filtered.where((it) {
                            final members =
                                (it['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
                                    const [];
                            return members.any((m) =>
                                m['user_id']?.toString() == currentUserId &&
                                m['status']?.toString() != 'cannot_attend');
                          }).toList();

                          final myInvites = filtered
                              .where((it) =>
                                  it['host_user_id']?.toString() ==
                                  currentUserId)
                              .toList();

                          final joinedInviteIds =
                              joinedInvites.map((it) => it['id']?.toString()).toSet();

                          final invitesForMe = filtered.where((it) {
                            final hostId = it['host_user_id']?.toString();
                            if (hostId == currentUserId) return false;
                            final id = it['id']?.toString();
                            if (id != null && joinedInviteIds.contains(id)) return false;
                            final groupId = it['group_id']?.toString();
                            if (groupId != null && groupId.isNotEmpty) return false;
                            return true;
                          }).toList();

                          final groupInvites = filtered.where((it) {
                            final mode = _normalizeMode((it['mode'] ?? '').toString());
                            return mode != 'one_to_one';
                          }).toList();

                          Widget buildList(List<Map<String, dynamic>> items) {
                            if (items.isEmpty) {
                              return Center(
                                child: Text(isSv
                                    ? 'Inga inbjudningar för filtret'
                                    : 'No invites for this filter'),
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
                                            constraints:
                                                const BoxConstraints(minHeight: 28),
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
                                            const SizedBox(width: 10),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _editInvite(it),
                                                  child: const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Icon(Icons.edit_outlined,
                                                        size: 22),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () => _deleteInvite(it),
                                                  child: const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Icon(Icons.delete_outline,
                                                        size: 22),
                                                  ),
                                                ),
                                              ],
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
                                      if ((it['group_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                    alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                    color: Colors.white24),
                                              ),
                                              child: Text(
                                                (it['group_name'] ?? '')
                                                    .toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              isSv ? 'Grupp' : 'Group',
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
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
                          }

                          return Column(
                            children: [
                              if (hasAnyInvites) ...[
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
                                const SizedBox(height: 12),
                              ],
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    buildList(invitesForMe),
                                    buildList(myInvites),
                                    buildList(joinedInvites),
                                    buildList(groupInvites),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
