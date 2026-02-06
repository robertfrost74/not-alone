import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../services/invites_repository.dart';
import '../services/invite_status.dart';
import '../services/error_mapper.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'groups_screen.dart';
import 'request_screen.dart';
import 'welcome_screen.dart';
import 'edit_invite_screen.dart';
import '../widgets/social_chrome.dart';
import '../widgets/invite_activity_filter.dart';
import '../widgets/invite_card.dart';
import '../widgets/invite_list.dart';
import '../widgets/nav_helper.dart';

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
  final Map<String, String> _hostNamesCache = {};
  bool _profilesLoaded = false;
  DateTime? _profilesLoadedAt;
  bool _offline = false;
  bool _loadingInvites = false;
  bool _realtimeFailed = false;
  DateTime? _lastJoinAttemptAt;
  static const Duration _profileCacheTtl = Duration(minutes: 5);
  static const Duration _joinCooldown = Duration(seconds: 2);
  final InvitesRepository _invitesRepository = InvitesRepository();

  String _activity = 'all'; // all|walk|coffee|workout|lunch|dinner

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

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
    if (_loadingInvites) return;
    setState(() {
      _invitesFuture = _loadInvites();
    });
  }

  void _startRealtime() {
    try {
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
    } catch (_) {
      if (mounted) {
        setState(() => _realtimeFailed = true);
      }
    }
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
    _loadingInvites = true;
    try {
      var invites = await _invitesRepository.fetchOpenInvites();
      if (mounted && _offline) {
        setState(() => _offline = false);
      }
      if (invites.isEmpty) return invites;

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final memberGroupIds =
            await _invitesRepository.fetchUserGroupIds(currentUserId);
        invites = invites.where((invite) {
          final groupId = invite['group_id']?.toString();
          if (groupId == null || groupId.isEmpty) return true;
          return memberGroupIds.contains(groupId);
        }).toList();
      }

      final shouldReloadProfiles = !_profilesLoaded ||
          _profilesLoadedAt == null ||
          DateTime.now().difference(_profilesLoadedAt!) > _profileCacheTtl;
      if (shouldReloadProfiles) {
        try {
          final profileNames = await _invitesRepository.fetchProfileNames();
          _hostNamesCache
            ..clear()
            ..addAll(profileNames);
          _profilesLoaded = true;
          _profilesLoadedAt = DateTime.now();
        } catch (_) {
          // Keep invites page resilient if profiles table/policies differ.
        }
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
          invite['host_display_name'] = _hostNamesCache[hostId] ?? fallback;
        }
        final group = invite['groups'] as Map<String, dynamic>?;
        invite['group_name'] = (group?['name'] ?? '').toString();
      }
      return invites;
    } catch (e) {
      if (mounted) {
        setState(() => _offline = isNetworkError(e));
      }
      return [];
    } finally {
      _loadingInvites = false;
    }
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

  bool _matchesActivityFilter(Map<String, dynamic> invite) {
    if (_activity == 'all') return true;
    final activity =
        _normalizeActivity((invite['activity'] ?? '').toString());
    return activity == _normalizeActivity(_activity);
  }

  bool _matchesAudience(Map<String, dynamic> invite) {
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
    if (_isJoinCooldownActive) return;
    _lastJoinAttemptAt = DateTime.now();
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invalid invite id', 'Ogiltigt invite-id'))),
      );
      return;
    }
    final status = _inviteStatus(invite);
    if (!_canJoinStatus(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Invite is not joinable', 'Inbjudan går inte att ansluta till'),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _joining = true;
    });
    try {
      final response = await Supabase.instance.client.rpc(
        'join_invite',
        params: {'invite_id': inviteId},
      );
      final inviteMemberId = response?.toString();
      if (inviteMemberId == null || inviteMemberId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('Could not join invite', 'Kunde inte gå med i inbjudan'),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      await context.pushNamedSafe(
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
      final message = mapSupabaseError(
        e,
        isSv: isSv,
        fallbackEn: 'Could not join invite',
        fallbackSv: 'Kunde inte gå med i inbjudan',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
    if (inviteId == null ||
        inviteId.isEmpty ||
        userId == null ||
        hostId != userId) {
      return;
    }

    final saved = await context.pushSafe<bool>(
      MaterialPageRoute(
        builder: (_) => EditInviteScreen(
          appState: widget.appState,
          invite: invite,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      _reloadInvites();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invite updated', 'Inbjudan uppdaterad'))),
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
    final maxValue = mode == 'one_to_one' ? 1 : maxParticipants;
    return maxValue == null ? '$accepted/-' : '$accepted/$maxValue';
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

  InviteStatus _inviteStatus(Map<String, dynamic> invite) {
    final meetingAt = _parseDateTime(invite['meeting_time']);
    final accepted = (invite['accepted_count'] as int?) ?? 0;
    final mode = _normalizeMode((invite['mode'] ?? '').toString());
    final rawMax = invite['max_participants'];
    final maxParticipants =
        rawMax is num ? rawMax.toInt() : int.tryParse(rawMax?.toString() ?? '');
    return computeInviteStatus(
      meetingAt: meetingAt,
      accepted: accepted,
      mode: mode,
      maxParticipants: maxParticipants,
    );
  }

  String _statusLabel(InviteStatus status) {
    switch (status) {
      case InviteStatus.full:
        return isSv ? 'Full' : 'Full';
      case InviteStatus.started:
        return isSv ? 'Startad' : 'Started';
      case InviteStatus.expired:
        return isSv ? 'Utgången' : 'Expired';
      case InviteStatus.open:
        return isSv ? 'Öppen' : 'Open';
    }
  }

  Color _statusColor(InviteStatus status) {
    switch (status) {
      case InviteStatus.full:
        return Colors.red.shade400;
      case InviteStatus.started:
        return Colors.blue.shade100;
      case InviteStatus.expired:
        return Colors.red.shade100;
      case InviteStatus.open:
        return Colors.green.shade100;
    }
  }

  bool _canJoinStatus(InviteStatus status) => status == InviteStatus.open;
  bool get _isJoinCooldownActive =>
      _lastJoinAttemptAt != null &&
      DateTime.now().difference(_lastJoinAttemptAt!) < _joinCooldown;

  String _joinButtonLabel(InviteStatus status) {
    switch (status) {
      case InviteStatus.full:
        return isSv ? 'Full' : 'Full';
      case InviteStatus.started:
        return isSv ? 'Startad' : 'Started';
      case InviteStatus.expired:
        return isSv ? 'Utgången' : 'Expired';
      case InviteStatus.open:
        return isSv ? 'Gå med' : 'Join';
    }
  }

  Widget _buildInviteCard(BuildContext context, Map<String, dynamic> it) {
    final place = (it['place'] ?? '').toString();
    final meetingTimeLabel = _formatDateTime(it['meeting_time']);
    final timeProgress =
        _timeLeftProgress(it['created_at'], it['meeting_time']);
    final timeLeftLabel = _timeLeftLabel(it['meeting_time']);
    final status = _inviteStatus(it);
    final canDelete = it['host_user_id']?.toString() ==
        Supabase.instance.client.auth.currentUser?.id;
    final groupName = (it['group_name'] ?? '').toString().trim();
    final genderNormalized =
        _normalizeGender((it['target_gender'] ?? 'all').toString());

    final placeLine = place.isEmpty
        ? null
        : isSv
            ? 'Mötesplats: $place'
            : 'Meeting place: $place';
    final groupLabel = groupName.isEmpty
        ? null
        : isSv
            ? 'Grupp'
            : 'Group';
    final genderTag = genderNormalized == 'all'
        ? null
        : genderNormalized == 'male'
            ? _t('Men', 'Män')
            : _t('Women', 'Kvinnor');

    return InviteCard(
      activityLabel: _activityLabel(it['activity']),
      hostDisplayName: (it['host_display_name'] ?? '').toString(),
      joinedLabel: _joinedOfMaxLabel(it),
      statusLabel: _statusLabel(status),
      statusColor: _statusColor(status),
      statusTextColor:
          status == InviteStatus.full ? Colors.white : Colors.black,
      canEdit: canDelete,
      onEdit: () => _editInvite(it),
      onDelete: () => _deleteInvite(it),
      countLabel: _countLabel(it),
      durationMinutes: int.tryParse(it['duration'].toString()) ?? 0,
      timeLine: isSv ? 'Tid: $meetingTimeLabel' : 'Time: $meetingTimeLabel',
      timeProgress: timeProgress,
      timeLeftLabel: timeLeftLabel,
      placeLine: placeLine,
      groupName: groupName.isEmpty ? null : groupName,
      groupLabel: groupLabel,
      genderTag: genderTag,
      joinEnabled: !_joining && _canJoinStatus(status) && !_isJoinCooldownActive,
      joinButtonLabel: _joinButtonLabel(status),
      onJoin: () => _joinInvite(it),
      onShowJoined: () => _showAcceptedUsersModal(it),
    );
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
              Tab(text: isSv ? 'Andras' : 'Others'),
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
                      child: OutlinedButton(
                        onPressed: () {
                          context.pushSafe(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestScreen(appState: widget.appState),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_t('Create invite', 'Skapa inbjudan')),
                      ),
                    ),
                    if (_offline || _realtimeFailed) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          _offline
                              ? _t('Offline. Trying to reconnect…',
                                  'Offline. Försöker ansluta…')
                              : _t('Live updates unavailable',
                                  'Live-uppdatering avstängd'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                          final activityFiltered =
                              allItems.where(_matchesActivityFilter).toList();
                          final hasAnyInvites = allItems.isNotEmpty;

                          final joinedInvites = activityFiltered.where((it) {
                            final members =
                                (it['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
                                    const [];
                            return members.any((m) =>
                                m['user_id']?.toString() == currentUserId &&
                                m['status']?.toString() != 'cannot_attend');
                          }).toList();

                          final myInvites = activityFiltered
                              .where((it) =>
                                  it['host_user_id']?.toString() ==
                                  currentUserId)
                              .toList();

                          final joinedInviteIds =
                              joinedInvites.map((it) => it['id']?.toString()).toSet();

                          final invitesForMe = activityFiltered.where((it) {
                            final hostId = it['host_user_id']?.toString();
                            if (hostId == currentUserId) return false;
                            final id = it['id']?.toString();
                            if (id != null && joinedInviteIds.contains(id)) return false;
                            final groupId = it['group_id']?.toString();
                            if (groupId != null && groupId.isNotEmpty) return false;
                            return _matchesAudience(it);
                          }).toList();

                          final groupInvites = activityFiltered.where((it) {
                            final groupId = it['group_id']?.toString();
                            if (groupId == null || groupId.isEmpty) return false;
                            if (it['host_user_id']?.toString() == currentUserId) {
                              return true;
                            }
                            return _matchesAudience(it);
                          }).toList();

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
                                InviteActivityFilter(
                                  isSv: isSv,
                                  value: _activity,
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
                                    InviteList(
                                      items: invitesForMe,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
                                    InviteList(
                                      items: myInvites,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
                                    InviteList(
                                      items: joinedInvites,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
                                    InviteList(
                                      items: groupInvites,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
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
