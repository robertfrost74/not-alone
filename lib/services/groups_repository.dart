import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsRepository {
  final SupabaseClient _client;

  GroupsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<int> fetchMemberCount(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('id')
        .match({'group_id': groupId});
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> fetchUserGroupRows(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('group_id, role, groups ( id, name, description, owner_id )')
        .match({'user_id': userId});
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchGroupInvitesByIdentifier(
      String identifier) async {
    final rows = await _client
        .from('group_invites')
        .select('id, group_id, identifier, groups ( id, name, description, owner_id )')
        .match({'identifier': identifier});
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('user_id, display_name')
        .match({'group_id': groupId});
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    final rows = await _client.from('profiles').select().match({'id': userId});
    return rows.isNotEmpty ? rows.first : <String, dynamic>{};
  }

  Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    final rows = await _client
        .from('user_blocks')
        .select('id')
        .match({'blocker_id': blockerId, 'blocked_id': blockedId});
    return rows.isNotEmpty;
  }
}
