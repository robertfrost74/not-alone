import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_mapper.dart';
import 'retry.dart';

class InvitesRepository {
  final SupabaseClient? _clientOverride;

  InvitesRepository({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchOpenInvites({
    int limit = 50,
    double? lat,
    double? lon,
    int radiusKm = 20,
    String? city,
  }) async {
    return withRetry(
      () async {
        final nearby = await fetchOpenInvitesNearby(
          limit: limit,
          lat: lat,
          lon: lon,
          radiusKm: radiusKm,
          city: city,
        );
        if (nearby.isNotEmpty) return nearby;
        return fetchOpenInvitesRaw(limit: limit);
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<List<Map<String, dynamic>>> fetchOpenInvitesRaw(
      {int limit = 50}) async {
    final res = await _client
        .from('invites')
        .select(
            'id, host_user_id, max_participants, target_gender, age_min, age_max, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, group_id, groups(name), invite_members(id,status,user_id)')
        .match({'status': 'open'})
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchJoinedInvitesForUser(
    String userId, {
    int limit = 500,
    int pageSize = 200,
  }) async {
    if (userId.isEmpty) return [];
    return withRetry(
      () async {
        final inviteIds = <String>{};
        var from = 0;
        while (inviteIds.length < limit) {
          final to = from + pageSize - 1;
          final rows = await fetchJoinedInviteMemberRows(
            userId,
            from: from,
            to: to,
          );
          for (final row in rows) {
            final inviteId = row['invite_id']?.toString();
            if (inviteId != null && inviteId.isNotEmpty) {
              inviteIds.add(inviteId);
              if (inviteIds.length >= limit) break;
            }
          }
          if (rows.length < pageSize) break;
          from += pageSize;
        }
        if (inviteIds.isEmpty) return <Map<String, dynamic>>[];

        final allInvites = <Map<String, dynamic>>[];
        final inviteIdList = inviteIds.toList(growable: false);
        for (var i = 0; i < inviteIdList.length; i += pageSize) {
          final end = (i + pageSize > inviteIdList.length)
              ? inviteIdList.length
              : i + pageSize;
          final chunk = inviteIdList.sublist(i, end);
          final chunkInvites = await fetchInvitesByIds(chunk.toSet());
          allInvites.addAll(chunkInvites);
        }

        final merged = <String, Map<String, dynamic>>{};
        for (final invite in allInvites) {
          final id = invite['id']?.toString();
          if (id == null || id.isEmpty) continue;
          invite['joined_by_current_user'] = true;
          merged[id] = invite;
        }
        final result = merged.values.toList(growable: false)
          ..sort((a, b) {
            final aCreated =
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            final bCreated =
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            return bCreated.compareTo(aCreated);
          });
        return result;
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<List<Map<String, dynamic>>> fetchJoinedInviteMemberRows(
    String userId, {
    required int from,
    required int to,
  }) async {
    final memberRows = await _client
        .from('invite_members')
        .select('invite_id')
        .eq('user_id', userId)
        .neq('status', 'cannot_attend')
        .range(from, to);
    return (memberRows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchInvitesByIds(
      Set<String> inviteIds) async {
    if (inviteIds.isEmpty) return const [];
    final invitesRes = await _client
        .from('invites')
        .select(
            'id, host_user_id, max_participants, target_gender, age_min, age_max, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, group_id, groups(name), invite_members(id,status,user_id)')
        .inFilter('id', inviteIds.toList())
        .order('created_at', ascending: false);
    return (invitesRes as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchOpenInvitesNearby({
    int limit = 50,
    double? lat,
    double? lon,
    int radiusKm = 20,
    String? city,
  }) async {
    if ((lat == null || lon == null) && (city == null || city.isEmpty)) {
      return [];
    }
    final res = await _client.rpc(
      'fetch_open_invites_nearby',
      params: {
        'p_lat': lat,
        'p_lon': lon,
        'p_radius_km': radiusKm,
        'p_city': city,
        'p_limit': limit,
      },
    );
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Set<String>> fetchUserGroupIds(String userId) async {
    return withRetry(
      () async {
        final groupRows = await _client
            .from('group_members')
            .select('group_id')
            .match({'user_id': userId});
        final memberGroupIds = <String>{};
        for (final row in groupRows.whereType<Map<String, dynamic>>()) {
          final id = row['group_id']?.toString();
          if (id != null && id.isNotEmpty) memberGroupIds.add(id);
        }
        return memberGroupIds;
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<Map<String, String>> fetchProfileNames({int limit = 2000}) async {
    return withRetry(
      () async {
        final profilesRes =
            await _client.from('profiles').select('id, username').limit(limit);
        final profileRows = (profilesRes as List).cast<Map<String, dynamic>>();
        final names = <String, String>{};
        for (final row in profileRows) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final username = (row['username'] ?? '').toString().trim();
          if (username.isNotEmpty) names[id] = username;
        }
        return names;
      },
      shouldRetry: isNetworkError,
    );
  }
}
