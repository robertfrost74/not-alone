import 'package:supabase_flutter/supabase_flutter.dart';

class InvitesRepository {
  final SupabaseClient _client;

  InvitesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchOpenInvites({int limit = 50}) async {
    final res = await _client
        .from('invites')
        .select(
            'id, host_user_id, max_participants, target_gender, age_min, age_max, created_at, activity, mode, energy, talk_level, duration, place, meeting_time, group_id, groups(name), invite_members(status,user_id)')
        .match({'status': 'open'})
        .order('created_at', ascending: false)
        .limit(limit);

    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Set<String>> fetchUserGroupIds(String userId) async {
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
  }

  Future<Map<String, String>> fetchProfileNames({int limit = 2000}) async {
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
  }
}
