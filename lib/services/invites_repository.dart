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
      () => fetchOpenInvitesNearby(
        limit: limit,
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
        city: city,
      ),
      shouldRetry: isNetworkError,
    );
  }

  Future<List<Map<String, dynamic>>> fetchOpenInvitesRaw(
      {int limit = 50}) async {
    final res = await _client
        .from('invites')
        .select(
            'id, host_user_id, max_participants, target_gender, age_min, age_max, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, group_id, groups(name), invite_members(status,user_id)')
        .match({'status': 'open'})
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
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
