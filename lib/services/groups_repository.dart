import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_mapper.dart';
import 'retry.dart';

class GroupsRepository {
  final SupabaseClient _client;

  GroupsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<int> fetchMemberCount(String groupId) async {
    return withRetry(
      () async {
        final rows = await _client
            .from('group_members')
            .select('id')
            .match({'group_id': groupId});
        return rows.length;
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<List<Map<String, dynamic>>> fetchUserGroupRows(String userId) async {
    return withRetry(
      () async {
        final rows = await _client
            .from('group_members')
            .select('group_id, role, groups ( id, name, description, owner_id )')
            .match({'user_id': userId});
        return rows.whereType<Map<String, dynamic>>().toList();
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<List<Map<String, dynamic>>> fetchGroupInvitesByIdentifier(
      String identifier) async {
    return withRetry(
      () async {
        final rows = await _client
            .from('group_invites')
            .select('id, group_id, identifier, groups ( id, name, description, owner_id )')
            .match({'identifier': identifier});
        return rows.whereType<Map<String, dynamic>>().toList();
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    return withRetry(
      () async {
        final rows = await _client
            .from('group_members')
            .select('user_id, display_name')
            .match({'group_id': groupId});
        return rows.whereType<Map<String, dynamic>>().toList();
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    return withRetry(
      () async {
        final rows =
            await _client.from('profiles').select().match({'id': userId});
        return rows.isNotEmpty ? rows.first : <String, dynamic>{};
      },
      shouldRetry: isNetworkError,
    );
  }

  Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    return withRetry(
      () async {
        final rows = await _client
            .from('user_blocks')
            .select('id')
            .match({'blocker_id': blockerId, 'blocked_id': blockedId});
        return rows.isNotEmpty;
      },
      shouldRetry: isNetworkError,
    );
  }
}
