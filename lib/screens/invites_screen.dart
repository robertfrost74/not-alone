import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../services/invites_repository.dart';
import '../services/invite_status.dart';
import '../services/error_mapper.dart';
import '../services/location_service.dart';
import '../services/profile_completion.dart';
import '../services/join_ui.dart';
import '../services/invite_buckets.dart';
import '../services/tab_switcher.dart';
import '../services/invite_counts.dart';
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
  final String? testCurrentUserId;
  final Map<String, dynamic>? testCurrentUserMetadata;
  final Future<List<Map<String, dynamic>>> Function()? testLoadInvites;
  final Future<String?> Function(String inviteId)? testJoinInvite;
  final Future<void> Function(String inviteMemberId)? testLeaveInvite;
  final Future<void> Function(String inviteId)? testDeleteInvite;

  const InvitesScreen({
    super.key,
    required this.appState,
    this.testCurrentUserId,
    this.testCurrentUserMetadata,
    this.testLoadInvites,
    this.testJoinInvite,
    this.testLeaveInvite,
    this.testDeleteInvite,
  });

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  final GlobalKey _tabRootKey = GlobalKey();
  String? _joiningInviteId;
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
  Set<String> _blockedUserIds = {};
  Set<String> _favoriteUserIds = {};
  final Set<String> _optimisticJoinedInviteIds = {};
  final Map<String, String> _optimisticMemberIds = {};
  List<Map<String, dynamic>> _cachedInvites = [];
  String _stableCurrentUserId = '';
  DateTime? _lastJoinAttemptAt;
  static const Duration _profileCacheTtl = Duration(minutes: 5);
  static const Duration _joinCooldown = Duration(seconds: 2);
  final InvitesRepository _invitesRepository = InvitesRepository();

  String _activity = 'all'; // all|walk|coffee|workout|lunch|dinner

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  String? get _currentUserId =>
      widget.testCurrentUserId ??
      Supabase.instance.client.auth.currentUser?.id;

  Map<String, dynamic>? get _currentUserMetadata =>
      widget.testCurrentUserMetadata ??
      Supabase.instance.client.auth.currentUser?.userMetadata;

  String get _effectiveCurrentUserId {
    final current = _currentUserId;
    if (current != null && current.isNotEmpty) {
      _stableCurrentUserId = current;
    }
    return _stableCurrentUserId;
  }

  int? get _currentUserAge {
    final metadata = _currentUserMetadata;
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
    final metadata = _currentUserMetadata;
    if (metadata == null) return null;
    final raw = metadata['gender']?.toString() ?? '';
    final normalized = _normalizeGender(raw);
    if (normalized != 'male' && normalized != 'female') return null;
    return normalized;
  }

  String _missingFieldLabel(String field) {
    switch (field) {
      case 'username':
        return _t('username', 'användarnamn');
      case 'age':
        return _t('age', 'ålder');
      case 'gender':
        return _t('gender', 'kön');
      case 'city':
        return _t('city', 'stad');
      default:
        return field;
    }
  }

  Future<bool> _ensureProfileCompleteForJoin() async {
    final metadata = _currentUserMetadata;
    final result = checkProfileCompletion(metadata);
    if (result.isComplete) return true;

    final missing = result.missingFields.map(_missingFieldLabel).join(', ');
    if (!mounted) return false;

    final goToProfile = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => SocialDialog(
            title: Text(_t('Complete profile', 'Fyll i profilen')),
            content: Text(
              _t(
                'Please complete your profile to join invites. Missing: $missing.',
                'Du behöver fylla i profilen för att gå med i inbjudningar. Saknas: $missing.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('Not now', 'Inte nu')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_t('Edit profile', 'Redigera profil')),
              ),
            ],
          ),
        ) ??
        false;

    if (goToProfile && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(appState: widget.appState),
        ),
      );
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _stableCurrentUserId = _currentUserId ?? '';
    _invitesFuture = _loadInvites();
    _startRealtime();
    _initLocation();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_realtimeFailed) _reloadInvites();
      setState(() {});
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

  void _removeInviteLocally(String inviteId) {
    _optimisticJoinedInviteIds.remove(inviteId);
    _optimisticMemberIds.remove(inviteId);
    final next = _cachedInvites
        .where((it) => it['id']?.toString() != inviteId)
        .toList(growable: false);
    _cachedInvites = next;
    if (!mounted) return;
    setState(() {
      _invitesFuture = Future.value(next);
    });
  }

  void _applyCreatedInvite(Map<String, dynamic> invite) {
    final normalized = Map<String, dynamic>.from(invite);
    final id = normalized['id']?.toString();
    if (id == null || id.isEmpty) return;

    final currentUserId = _effectiveCurrentUserId;
    normalized['accepted_count'] = computeAcceptedCount(
      members: (normalized['invite_members'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [],
      inviteId: id,
      optimisticJoinedIds: _optimisticJoinedInviteIds,
      currentUserId: currentUserId,
    );

    final username = (_currentUserMetadata?['username'] ?? '').toString().trim();
    if (username.isNotEmpty) {
      normalized['host_display_name'] = username;
    } else if ((normalized['host_display_name'] ?? '').toString().isEmpty) {
      normalized['host_display_name'] = _t('You', 'Du');
    }

    final group = normalized['groups'] as Map<String, dynamic>?;
    normalized['group_name'] = (group?['name'] ?? normalized['group_name'] ?? '')
        .toString();

    final next = _cachedInvites
        .where((it) => it['id']?.toString() != id)
        .toList(growable: true)
      ..insert(0, normalized);

    _cachedInvites = next;
    if (!mounted) return;
    setState(() {
      _invitesFuture = Future.value(next);
    });
  }

  void _startRealtime() {
    if (widget.testLoadInvites != null) return;
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

  Future<void> _initLocation() async {
    if (widget.testLoadInvites != null) return;
    final metadataCity = (Supabase.instance.client.auth.currentUser?.userMetadata?['city'] ?? '')
        .toString()
        .trim();
    if (widget.appState.city == null && metadataCity.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.appState.setCity(metadataCity);
      });
    }

    final position = await LocationService().getPosition(allowPrompt: false);
    if (!mounted || position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.appState
          .setLocation(lat: position.latitude, lon: position.longitude);
    });
    _reloadInvites();
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

  Future<Set<String>> _fetchBlockedUserIds(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('user_blocks')
          .select('blocked_id')
          .match({'blocker_id': userId});
      final blockedIds = <String>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = row['blocked_id']?.toString();
        if (id != null && id.isNotEmpty) blockedIds.add(id);
      }
      return blockedIds;
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _fetchFavoriteUserIds(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('user_favorites')
          .select('target_user_id')
          .match({'user_id': userId});
      final favorites = <String>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final id = row['target_user_id']?.toString();
        if (id != null && id.isNotEmpty) favorites.add(id);
      }
      return favorites;
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _loadInvites() async {
    _loadingInvites = true;
    try {
      if (widget.testLoadInvites != null) {
        final invites = await widget.testLoadInvites!.call();
        _cachedInvites = invites;
        return invites;
      }
      var invites = await _invitesRepository.fetchOpenInvites(
        lat: widget.appState.currentLat,
        lon: widget.appState.currentLon,
        radiusKm: 20,
        city: widget.appState.city,
      );
      if (invites.isEmpty && widget.appState.city != null) {
        invites = await _invitesRepository.fetchOpenInvites(
          lat: null,
          lon: null,
          radiusKm: 20,
          city: widget.appState.city,
        );
      }
      if (mounted && _offline) {
        setState(() => _offline = false);
      }
      if (invites.isEmpty) {
        _cachedInvites = invites;
        return invites;
      }

      final currentUserId = _effectiveCurrentUserId;
      if (currentUserId.isNotEmpty) {
        final blockedIds = await _fetchBlockedUserIds(currentUserId);
        if (mounted) {
          setState(() => _blockedUserIds = blockedIds);
        } else {
          _blockedUserIds = blockedIds;
        }
        final favoriteIds = await _fetchFavoriteUserIds(currentUserId);
        if (mounted) {
          setState(() => _favoriteUserIds = favoriteIds);
        } else {
          _favoriteUserIds = favoriteIds;
        }
        invites = invites.where((invite) {
          final hostId = invite['host_user_id']?.toString();
          if (hostId == null || hostId.isEmpty) return true;
          return !blockedIds.contains(hostId);
        }).toList();

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

      final currentUsername =
          (_currentUserMetadata?['username'] ?? '').toString().trim();
      final currentDisplay = currentUsername.isNotEmpty ? currentUsername : '';

      for (final invite in invites) {
        final members =
            (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];
        invite['accepted_count'] = computeAcceptedCount(
          members: members,
          inviteId: invite['id']?.toString(),
          optimisticJoinedIds: _optimisticJoinedInviteIds,
          currentUserId: currentUserId,
        );
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
      _cachedInvites = invites;
      return invites;
    } catch (e) {
      if (mounted) {
        setState(() => _offline = isNetworkError(e));
      }
      if (_cachedInvites.isNotEmpty) return _cachedInvites;
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
    final canProceed = await _ensureProfileCompleteForJoin();
    if (!canProceed || !mounted) return;

    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invalid invite id', 'Ogiltigt invite-id'))),
      );
      return;
    }

    final hostId = invite['host_user_id']?.toString();
    if (hostId != null && hostId.isNotEmpty && _blockedUserIds.contains(hostId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'You blocked this user. Unblock to join.',
              'Du har blockerat användaren. Avblockera för att gå med.',
            ),
          ),
        ),
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
      _joiningInviteId = inviteId;
    });
    try {
      final inviteMemberId = widget.testJoinInvite != null
          ? await widget.testJoinInvite!(inviteId)
          : (await Supabase.instance.client.rpc(
              'join_invite',
              params: {'invite_id': inviteId},
            ))
              ?.toString();
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
      _optimisticJoinedInviteIds.add(inviteId);
      _optimisticMemberIds[inviteId] = inviteMemberId;
      setState(() {});
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
          _joiningInviteId = null;
        });
      }
    }
  }

  Future<void> _editInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    final hostId = invite['host_user_id']?.toString();
    final userId = _effectiveCurrentUserId;
    if (inviteId == null ||
        inviteId.isEmpty ||
        userId.isEmpty ||
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
      if (widget.testDeleteInvite != null) {
        await widget.testDeleteInvite!(inviteId);
      } else {
        // Clean up dependent rows first to avoid FK delete errors.
        await Supabase.instance.client
            .from('invite_members')
            .delete()
            .match({'invite_id': inviteId});
        await Supabase.instance.client
            .from('meetups')
            .delete()
            .match({'invite_id': inviteId});
        await _softDeleteInvite(inviteId);
      }
      if (!mounted) return;
      _removeInviteLocally(inviteId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    }
  }

  Future<void> _softDeleteInvite(String inviteId) async {
    await Supabase.instance.client
        .rpc('soft_delete_invite', params: {'p_invite_id': inviteId});
  }

  Future<void> _showInviteActions(Map<String, dynamic> invite) async {
    final hostId = invite['host_user_id']?.toString() ?? '';
    if (hostId.isEmpty) return;
    final hostName = (invite['host_display_name'] ?? '').toString().trim();
    final isBlocked = _blockedUserIds.contains(hostId);
    final isFavorite = _favoriteUserIds.contains(hostId);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0F1A1A),
      builder: (sheetContext) {
        return SafeArea(
          child: SocialSheetContent(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hostName.isEmpty
                        ? _t('User actions', 'Åtgärder')
                        : _t('Actions for $hostName', 'Åtgärder för $hostName'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showInviteQuestions(invite);
                    },
                    icon: const Icon(Icons.question_answer_outlined),
                    label: Text(_t('Ask organizer', 'Fråga arrangören')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _toggleFavorite(hostId, isFavorite);
                    },
                    icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                    label: Text(
                      isFavorite
                          ? _t('Remove favorite', 'Ta bort favorit')
                          : _t('Favorite user', 'Favoritmarkera användare'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _reportUser(invite);
                    },
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(_t('Report user', 'Rapportera användare')),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isBlocked ? Colors.white24 : const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _toggleBlock(hostId, isBlocked);
                    },
                    icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                    label: Text(
                      isBlocked ? _t('Unblock', 'Avblockera') : _t('Block', 'Blockera'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleBlock(String userId, bool isBlocked) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    try {
      if (isBlocked) {
        await Supabase.instance.client.from('user_blocks').delete().match({
          'blocker_id': currentUser.id,
          'blocked_id': userId,
        });
      } else {
        await Supabase.instance.client.from('user_blocks').insert({
          'blocker_id': currentUser.id,
          'blocked_id': userId,
        });
      }
      if (!mounted) return;
      _reloadInvites();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBlocked
                ? _t('User unblocked', 'Användaren avblockerad')
                : _t('User blocked', 'Användaren blockerad'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    }
  }

  Future<void> _toggleFavorite(String userId, bool isFavorite) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    try {
      if (isFavorite) {
        await Supabase.instance.client.from('user_favorites').delete().match({
          'user_id': currentUser.id,
          'target_user_id': userId,
        });
        _favoriteUserIds.remove(userId);
      } else {
        await Supabase.instance.client.from('user_favorites').insert({
          'user_id': currentUser.id,
          'target_user_id': userId,
        });
        _favoriteUserIds.add(userId);
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? _t('Favorite removed', 'Favorit borttagen')
                : _t('Added to favorites', 'Tillagd som favorit'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchInviteComments(
      String inviteId) async {
    final rows = await Supabase.instance.client
        .from('invite_comments')
        .select('id, author_id, author_name, body, created_at')
        .match({'invite_id': inviteId})
        .order('created_at', ascending: true)
        .limit(100);
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _showInviteQuestions(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    if (inviteId == null || inviteId.isEmpty) return;
    final hostId = invite['host_user_id']?.toString();
    final hostName = (invite['host_display_name'] ?? '').toString().trim();
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    List<Map<String, dynamic>> comments = [];
    bool loading = true;
    bool submitting = false;
    final controller = TextEditingController();

    try {
      comments = await _fetchInviteComments(inviteId);
    } catch (_) {
      comments = [];
    } finally {
      loading = false;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0F1A1A),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final text = controller.text.trim();
              if (text.isEmpty || submitting) return;
              setState(() => submitting = true);
              final authorName = (currentUser.userMetadata?['username'] ?? '')
                  .toString()
                  .trim();
              final fallback = currentUser.email?.split('@').first ?? 'User';
              try {
                await Supabase.instance.client.from('invite_comments').insert({
                  'invite_id': inviteId,
                  'author_id': currentUser.id,
                  'author_name': authorName.isEmpty ? fallback : authorName,
                  'body': text,
                });
                controller.clear();
                comments = await _fetchInviteComments(inviteId);
                setState(() {});
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
                );
              } finally {
                if (mounted) {
                  setState(() => submitting = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hostName.isEmpty
                          ? _t('Questions', 'Frågor')
                          : _t('Questions for $hostName', 'Frågor till $hostName'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : comments.isEmpty
                              ? Center(
                                  child: Text(
                                    _t(
                                      'No questions yet.',
                                      'Inga frågor ännu.',
                                    ),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: comments.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = comments[index];
                                    final author =
                                        (item['author_name'] ?? '').toString();
                                    final created =
                                        _formatDateTime(item['created_at']);
                                    final body =
                                        (item['body'] ?? '').toString();
                                    final isHost = hostId != null &&
                                        hostId.isNotEmpty &&
                                        item['author_id']?.toString() == hostId;
                                    return Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            Border.all(color: Colors.white24),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                author.isEmpty
                                                    ? _t('User', 'Användare')
                                                    : author,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (isHost) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  _t('(host)', '(värd)'),
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              Text(
                                                created,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            body,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        hintText: _t(
                          'Write a question...',
                          'Skriv en fråga...',
                        ),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: submitting ? null : submit,
                        child: Text(
                          submitting
                              ? _t('Sending...', 'Skickar...')
                              : _t('Send', 'Skicka'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _reportUser(Map<String, dynamic> invite) async {
    final hostId = invite['host_user_id']?.toString() ?? '';
    if (hostId.isEmpty) return;
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final reasons = [
      ('spam', _t('Spam', 'Spam')),
      ('inappropriate', _t('Inappropriate content', 'Olämpligt innehåll')),
      ('fake', _t('Fake profile', 'Falsk profil')),
      ('harassment', _t('Harassment', 'Trakasserier')),
      ('other', _t('Other', 'Annat')),
    ];
    var selected = reasons.first.$1;
    final detailsController = TextEditingController();

    final submit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => SocialDialog(
              title: Text(_t('Report user', 'Rapportera användare')),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t('Reason', 'Anledning')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons
                        .map(
                          (reason) => SocialChoiceChip(
                            label: reason.$2,
                            selected: selected == reason.$1,
                            onSelected: (_) => setState(() {
                              selected = reason.$1;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(_t('Details (optional)', 'Detaljer (valfritt)')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _t('Tell us what happened', 'Beskriv vad som hänt'),
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_t('Cancel', 'Avbryt')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(_t('Submit report', 'Skicka rapport')),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!submit) {
      detailsController.dispose();
      return;
    }

    final details = detailsController.text.trim();
    detailsController.dispose();

    try {
      await Supabase.instance.client.from('user_reports').insert({
        'reporter_id': currentUser.id,
        'reported_id': hostId,
        'invite_id': invite['id'],
        'reason': selected,
        'details': details.isEmpty ? null : details,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Report submitted', 'Rapport skickad'),
          ),
        ),
      );
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
    final accepted = _acceptedCount(invite);
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
    final accepted = _acceptedCount(invite);
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

  int _acceptedCount(Map<String, dynamic> invite) {
    final members =
        (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    return computeAcceptedCount(
      members: members,
      inviteId: invite['id']?.toString(),
      optimisticJoinedIds: _optimisticJoinedInviteIds,
      currentUserId: _effectiveCurrentUserId,
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

  bool _isJoinedByCurrentUser(Map<String, dynamic> invite) {
    final currentUserId = _effectiveCurrentUserId;
    if (currentUserId.isEmpty) return false;
    final members =
        (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    final joined = members.any((m) =>
        m['user_id']?.toString() == currentUserId &&
        m['status']?.toString() != 'cannot_attend');
    if (joined) return true;
    final inviteId = invite['id']?.toString();
    return inviteId != null && _optimisticJoinedInviteIds.contains(inviteId);
  }

  String? _currentMemberId(Map<String, dynamic> invite) {
    final currentUserId = _effectiveCurrentUserId;
    if (currentUserId.isEmpty) return null;
    final members =
        (invite['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    for (final m in members) {
      if (m['user_id']?.toString() == currentUserId &&
          m['status']?.toString() != 'cannot_attend') {
        return m['id']?.toString();
      }
    }
    final inviteId = invite['id']?.toString();
    if (inviteId != null) {
      return _optimisticMemberIds[inviteId];
    }
    return null;
  }

  Future<void> _leaveInvite(Map<String, dynamic> invite) async {
    final inviteId = invite['id']?.toString();
    final memberId = _currentMemberId(invite);
    if (inviteId == null || inviteId.isEmpty || memberId == null) return;
    try {
      if (widget.testLeaveInvite != null) {
        await widget.testLeaveInvite!(memberId);
      } else {
        await Supabase.instance.client.rpc(
          'leave_invite',
          params: {'invite_member_id': memberId},
        );
      }
      _optimisticJoinedInviteIds.remove(inviteId);
      _optimisticMemberIds.remove(inviteId);
      final currentUserId = _effectiveCurrentUserId;
      if (currentUserId.isNotEmpty) {
        void markLeft(Map<String, dynamic> target) {
          final members =
              (target['invite_members'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
          for (final member in members) {
            if (member['user_id']?.toString() == currentUserId) {
              member['status'] = 'cannot_attend';
            }
          }
        }

        markLeft(invite);
        for (final cached in _cachedInvites) {
          if (cached['id']?.toString() != inviteId) continue;
          markLeft(cached);
        }
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    }
  }

  Widget _buildInviteCard(BuildContext context, Map<String, dynamic> it) {
    final place = (it['place'] ?? '').toString();
    final meetingTimeLabel = _formatDateTime(it['meeting_time']);
    final timeProgress =
        _timeLeftProgress(it['created_at'], it['meeting_time']);
    final timeLeftLabel = _timeLeftLabel(it['meeting_time']);
    final status = _inviteStatus(it);
    final inviteId = it['id']?.toString();
    final currentUserId = _effectiveCurrentUserId;
    final hostId = it['host_user_id']?.toString();
    final canDelete = hostId != null && hostId == currentUserId;
    final canShowActions =
        hostId != null && hostId.isNotEmpty && hostId != currentUserId;
    final isJoined = _isJoinedByCurrentUser(it);
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

    final joinUi = computeJoinUiState(
      inviteId: inviteId,
      joiningInviteId: _joiningInviteId,
      canJoin: _canJoinStatus(status),
      isJoinCooldownActive: _isJoinCooldownActive,
      isSv: isSv,
      defaultLabel: isJoined ? _t('Leave', 'Lämna') : _joinButtonLabel(status),
    );

    final isHostInvite = canDelete;
    final joinButtonLabel =
        isHostInvite ? _t('Delete', 'Radera') : joinUi.label;
    final onJoinAction = isHostInvite
        ? () => _deleteInvite(it)
        : () => isJoined ? _leaveInvite(it) : _joinInvite(it);
    final joinEnabled = isHostInvite ? true : (isJoined ? true : joinUi.enabled);

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
      joinEnabled: joinEnabled,
      joinButtonLabel: joinButtonLabel,
      onJoin: onJoinAction,
      onShowJoined: () => _showAcceptedUsersModal(it),
      onMore: canShowActions ? () => _showInviteActions(it) : null,
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
              scheduleTabSwitch(tabRootKey: _tabRootKey, index: 0);
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
                    key: _tabRootKey,
                    children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () async {
                          final result = await context.pushSafe<Object?>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestScreen(appState: widget.appState),
                            ),
                          );
                          final payload = result is Map
                              ? Map<String, dynamic>.from(result)
                              : null;
                          final created = result == true ||
                              (payload?['created'] == true);
                          final createdInvite = payload?['invite'];

                          if (created == true && mounted) {
                            if (createdInvite is Map<String, dynamic>) {
                              _applyCreatedInvite(createdInvite);
                            } else {
                              _reloadInvites();
                            }
                            scheduleTabSwitch(tabRootKey: _tabRootKey, index: 1);
                          }
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
                    if (_joiningInviteId != null)
                      const LinearProgressIndicator(),
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
                          final hasLocationOrCity =
                              widget.appState.hasLocationOrCity;
                          if (allItems.isEmpty && !hasLocationOrCity) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _t(
                                      'Add your city or enable location to see nearby invites.',
                                      'Lägg till stad eller aktivera plats för att se inbjudningar.',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () {
                                      context.pushSafe(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProfileScreen(appState: widget.appState),
                                        ),
                                      );
                                    },
                                    child: Text(_t('Set city', 'Ange stad')),
                                  ),
                                ],
                              ),
                            );
                          }
                          final currentUserId = _effectiveCurrentUserId;
                          final activityFiltered =
                              allItems.where(_matchesActivityFilter).toList();
                          final hasAnyInvites = allItems.isNotEmpty;

                          final buckets = bucketInvites(
                            activityFiltered: activityFiltered,
                            currentUserId: currentUserId,
                            optimisticJoinedIds: _optimisticJoinedInviteIds,
                            matchesAudience: _matchesAudience,
                          );

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
                                      items: buckets.invitesForMe,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
                                    InviteList(
                                      items: buckets.myInvites,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
                                    InviteList(
                                      items: buckets.joinedInvites,
                                      emptyLabel: isSv
                                          ? 'Inga inbjudningar för filtret'
                                          : 'No invites for this filter',
                                      itemBuilder: _buildInviteCard,
                                    ),
                                    InviteList(
                                      items: buckets.groupInvites,
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
