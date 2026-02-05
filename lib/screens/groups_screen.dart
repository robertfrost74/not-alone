import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';
import 'create_group_screen.dart';

class GroupCard {
  final String id;
  final String name;
  final String description;
  final int membersCount;
  final bool isOwner;
  final String? ownerName;

  const GroupCard({
    required this.id,
    required this.name,
    required this.description,
    required this.membersCount,
    this.isOwner = false,
    this.ownerName,
  });
}

class GroupsScreen extends StatefulWidget {
  final AppState appState;
  final GroupCard? initialGroup;

  const GroupsScreen({
    super.key,
    required this.appState,
    this.initialGroup,
  });

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<GroupCard> _ownedGroups = [];
  final List<GroupCard> _memberGroups = [];
  final List<GroupCard> _pendingInvites = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _channel = supabase.channel('groups_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (_) => _refreshAll(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_invites',
        callback: (_) => _refreshAll(),
      )
      ..subscribe();
  }

  Future<int> _memberCount(String groupId) async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('group_members')
        .select('id')
        .match({'group_id': groupId});
    if (rows is List) return rows.length;
    return 0;
  }

  Future<List<GroupCard>> _loadGroups() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final rows = await supabase
        .from('group_members')
        .select('group_id, role, groups ( id, name, description, owner_id )')
        .match({'user_id': user.id});

    if (rows is! List) return [];

    final groupEntries = rows
        .whereType<Map<String, dynamic>>()
        .map((row) => row['groups'] as Map<String, dynamic>)
        .toList();

    final List<GroupCard> cards = [];
    for (final group in groupEntries) {
      final groupId = group['id']?.toString() ?? '';
      if (groupId.isEmpty) continue;
      final count = await _memberCount(groupId);
      cards.add(
        GroupCard(
          id: groupId,
          name: (group['name'] ?? '').toString(),
          description: (group['description'] ?? '').toString(),
          membersCount: count,
          isOwner: (group['owner_id'] ?? '').toString() == user.id,
        ),
      );
    }

    if (widget.initialGroup != null) {
      cards.add(
        GroupCard(
          id: widget.initialGroup!.id,
          name: widget.initialGroup!.name,
          description: widget.initialGroup!.description,
          membersCount: widget.initialGroup!.membersCount,
          isOwner: true,
          ownerName: widget.initialGroup!.ownerName,
        ),
      );
    }

    return cards;
  }

  Future<List<GroupCard>> _loadInvites() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final username =
        (user.userMetadata?['username'] ?? '').toString().trim();
    final email = (user.email ?? '').trim();

    final List<Map<String, dynamic>> inviteRows = [];
    if (email.isNotEmpty) {
      final rows = await supabase
          .from('group_invites')
          .select('id, group_id, identifier, groups ( id, name, description, owner_id )')
          .match({'identifier': email});
      if (rows is List) {
        inviteRows.addAll(rows.whereType<Map<String, dynamic>>());
      }
    }
    if (username.isNotEmpty) {
      final rows = await supabase
          .from('group_invites')
          .select('id, group_id, identifier, groups ( id, name, description, owner_id )')
          .match({'identifier': username});
      if (rows is List) {
        inviteRows.addAll(rows.whereType<Map<String, dynamic>>());
      }
    }

    final seen = <String>{};
    final List<GroupCard> cards = [];
    for (final row in inviteRows) {
      final group = row['groups'] as Map<String, dynamic>?;
      if (group == null) continue;
      final groupId = group['id']?.toString() ?? '';
      if (groupId.isEmpty || seen.contains(groupId)) continue;
      seen.add(groupId);
      final count = await _memberCount(groupId);
      cards.add(
        GroupCard(
          id: groupId,
          name: (group['name'] ?? '').toString(),
          description: (group['description'] ?? '').toString(),
          membersCount: count,
          isOwner: (group['owner_id'] ?? '').toString() == user.id,
          ownerName: null,
        ),
      );
    }
    return cards;
  }

  Future<void> _refreshAll() async {
    if (mounted) setState(() => _loading = true);
    try {
      final groups = await _loadGroups();
      final invites = await _loadInvites();
      if (!mounted) return;
      setState(() {
        _ownedGroups
          ..clear()
          ..addAll(groups.where((g) => g.isOwner));
        _memberGroups
          ..clear()
          ..addAll(groups.where((g) => !g.isOwner));
        _pendingInvites
          ..clear()
          ..addAll(invites);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptInvite(GroupCard group) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('group_members').insert({
        'group_id': group.id,
        'user_id': user.id,
        'role': 'member',
      });

      final username =
          (user.userMetadata?['username'] ?? '').toString().trim();
      final email = (user.email ?? '').trim();
      if (email.isNotEmpty) {
        await supabase
            .from('group_invites')
            .delete()
            .match({'group_id': group.id, 'identifier': email});
      }
      if (username.isNotEmpty) {
        await supabase
            .from('group_invites')
            .delete()
            .match({'group_id': group.id, 'identifier': username});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Joined group', 'Du gick med i gruppen'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Could not join group', 'Kunde inte gå med'))),
        );
      }
    } finally {
      _refreshAll();
    }
  }

  Future<void> _leaveGroup(GroupCard group) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('group_members').delete().match({
        'group_id': group.id,
        'user_id': user.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Left group', 'Du lämnade gruppen'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Could not leave group', 'Kunde inte lämna gruppen'))),
        );
      }
    } finally {
      _refreshAll();
    }
  }

  Future<void> _confirmLeave(GroupCard group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A1A),
        title: Text(
          _t('Leave group?', 'Lämna grupp?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            'You can rejoin if you get invited again.',
            'Du kan gå med igen om du blir inbjuden.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'Avbryt')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Leave', 'Lämna')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _leaveGroup(group);
    }
  }

  Future<void> _deleteGroup(GroupCard group) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('groups').delete().match({
        'id': group.id,
        'owner_id': user.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Group deleted', 'Gruppen raderad'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Could not delete group', 'Kunde inte radera gruppen'))),
        );
      }
    } finally {
      _refreshAll();
    }
  }

  Future<void> _confirmDelete(GroupCard group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A1A),
        title: Text(
          _t('Delete group?', 'Radera grupp?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _t(
            'This will remove the group for everyone.',
            'Det här tar bort gruppen för alla.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'Avbryt')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: Text(_t('Delete', 'Radera')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteGroup(group);
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildGroupCard(GroupCard group) {
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
          Text(
            group.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              group.description,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _t('Members: ', 'Medlemmar: ') + group.membersCount.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (group.isOwner)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4CF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _t('Owner', 'Ägare'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        onPressed: () => _confirmDelete(group),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _t('Delete', 'Radera'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (group.ownerName != null &&
                  group.ownerName!.trim().isNotEmpty)
                Text(
                  group.ownerName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (!group.isOwner) ...[
                const SizedBox(width: 10),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () => _confirmLeave(group),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _t('Leave', 'Lämna'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<GroupCard> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(title),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          Text(
            _t('No groups yet', 'Inga grupper ännu'),
            style: const TextStyle(color: Colors.white60),
          )
        else
          ...groups
              .map((group) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGroupCard(group),
                  ))
              .toList(),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _invitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_t('Invites', 'Inbjudningar')),
        const SizedBox(height: 10),
        if (_pendingInvites.isEmpty)
          Text(
            _t('No invites yet', 'Inga inbjudningar ännu'),
            style: const TextStyle(color: Colors.white60),
          )
        else
          ..._pendingInvites.map((group) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (group.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              group.description,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: () => _acceptInvite(group),
                        child: Text(_t('Join', 'Gå med')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Groups', 'Grupper')),
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
                  builder: (_) => CreateGroupScreen(appState: widget.appState),
                ),
              );
            },
          ),
        ],
      ),
      body: SocialBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        _invitesSection(),
                        _section(
                          _t('My groups', 'Mina grupper'),
                          _ownedGroups,
                        ),
                        _section(
                          _t('Groups I joined', 'Grupper jag är med i'),
                          _memberGroups,
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
