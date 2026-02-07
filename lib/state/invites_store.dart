import 'package:flutter/foundation.dart';

class InvitesStore extends ChangeNotifier {
  String? _joiningInviteId;
  bool _offline = false;
  bool _loadingInvites = false;
  bool _reloadQueued = false;
  bool _joinedSyncDegraded = false;
  bool _realtimeFailed = false;
  Set<String> _blockedUserIds = {};
  Set<String> _favoriteUserIds = {};
  final Set<String> _optimisticJoinedInviteIds = {};
  final Map<String, String> _optimisticMemberIds = {};
  List<Map<String, dynamic>> _cachedInvites = [];
  String _cachedInvitesUserId = '';
  String _stableCurrentUserId = '';
  final Map<String, String> _hostNamesCache = {};
  bool _profilesLoaded = false;
  DateTime? _profilesLoadedAt;
  late Future<List<Map<String, dynamic>>> _invitesFuture;

  String? get joiningInviteId => _joiningInviteId;
  bool get offline => _offline;
  bool get loadingInvites => _loadingInvites;
  bool get reloadQueued => _reloadQueued;
  bool get joinedSyncDegraded => _joinedSyncDegraded;
  bool get realtimeFailed => _realtimeFailed;
  Set<String> get blockedUserIds => _blockedUserIds;
  Set<String> get favoriteUserIds => _favoriteUserIds;
  Set<String> get optimisticJoinedInviteIds => _optimisticJoinedInviteIds;
  Map<String, String> get optimisticMemberIds => _optimisticMemberIds;
  List<Map<String, dynamic>> get cachedInvites => _cachedInvites;
  String get cachedInvitesUserId => _cachedInvitesUserId;
  String get stableCurrentUserId => _stableCurrentUserId;
  Map<String, String> get hostNamesCache => _hostNamesCache;
  bool get profilesLoaded => _profilesLoaded;
  DateTime? get profilesLoadedAt => _profilesLoadedAt;
  Future<List<Map<String, dynamic>>> get invitesFuture => _invitesFuture;

  set joiningInviteId(String? value) {
    _joiningInviteId = value;
    notifyListeners();
  }

  set offline(bool value) {
    _offline = value;
    notifyListeners();
  }

  set loadingInvites(bool value) {
    _loadingInvites = value;
  }

  set reloadQueued(bool value) {
    _reloadQueued = value;
  }

  set joinedSyncDegraded(bool value) {
    _joinedSyncDegraded = value;
    notifyListeners();
  }

  set realtimeFailed(bool value) {
    _realtimeFailed = value;
    notifyListeners();
  }

  set blockedUserIds(Set<String> value) {
    _blockedUserIds = value;
    notifyListeners();
  }

  set favoriteUserIds(Set<String> value) {
    _favoriteUserIds = value;
    notifyListeners();
  }

  set cachedInvites(List<Map<String, dynamic>> value) {
    _cachedInvites = value;
  }

  set cachedInvitesUserId(String value) {
    _cachedInvitesUserId = value;
  }

  set stableCurrentUserId(String value) {
    _stableCurrentUserId = value;
  }

  set profilesLoaded(bool value) {
    _profilesLoaded = value;
  }

  set profilesLoadedAt(DateTime? value) {
    _profilesLoadedAt = value;
  }

  set invitesFuture(Future<List<Map<String, dynamic>>> value) {
    _invitesFuture = value;
    notifyListeners();
  }

  void clearUserScopedState() {
    _cachedInvites = [];
    _cachedInvitesUserId = '';
    _optimisticJoinedInviteIds.clear();
    _optimisticMemberIds.clear();
    notifyListeners();
  }
}
