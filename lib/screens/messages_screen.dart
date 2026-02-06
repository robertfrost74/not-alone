import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';
import 'direct_chat_screen.dart';
import 'group_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final AppState appState;

  const ChatsScreen({super.key, required this.appState});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final List<Map<String, dynamic>> _directChats = [];
  final List<Map<String, dynamic>> _groupChats = [];
  final Map<String, Map<String, dynamic>> _groupLatest = {};
  bool _loading = true;
  RealtimeChannel? _dmSent;
  RealtimeChannel? _dmRecv;
  RealtimeChannel? _groupChannel;

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _dmSent?.unsubscribe();
    _dmRecv?.unsubscribe();
    _groupChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _dmSent = supabase.channel('dm_sent_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'direct_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: user.id,
        ),
        callback: (_) => _loadChats(),
      )
      ..subscribe();

    _dmRecv = supabase.channel('dm_recv_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'direct_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: user.id,
        ),
        callback: (_) => _loadChats(),
      )
      ..subscribe();

    _groupChannel = supabase.channel('group_messages_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_messages',
        callback: (_) => _loadChats(),
      )
      ..subscribe();
  }

  Future<void> _loadChats() async {
    if (mounted) setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final sent = await supabase
        .from('direct_messages')
        .select()
        .match({'sender_id': user.id});
    final received = await supabase
        .from('direct_messages')
        .select()
        .match({'recipient_id': user.id});

    final all = <Map<String, dynamic>>[];
    all.addAll(sent.whereType<Map<String, dynamic>>());
    all.addAll(received.whereType<Map<String, dynamic>>());

    all.sort((a, b) {
      final ad = DateTime.tryParse((a['created_at'] ?? '').toString());
      final bd = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    final Map<String, Map<String, dynamic>> latestByUser = {};
    for (final msg in all) {
      final sender = (msg['sender_id'] ?? '').toString();
      final recipient = (msg['recipient_id'] ?? '').toString();
      final otherId = sender == user.id ? recipient : sender;
      if (otherId.isEmpty) continue;
      if (!latestByUser.containsKey(otherId)) {
        latestByUser[otherId] = msg;
      }
    }

    final groupRows = await supabase
        .from('group_members')
        .select('group_id, groups ( id, name )')
        .match({'user_id': user.id});
    final groups = groupRows.whereType<Map<String, dynamic>>().toList();

    final groupIds = groups
        .map((row) => row['group_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final latestByGroup = <String, Map<String, dynamic>>{};
    if (groupIds.isNotEmpty) {
      final gRows = await supabase
          .from('group_messages')
          .select('group_id, body, sender_name, created_at')
          .inFilter('group_id', groupIds)
          .order('created_at', ascending: false);
      for (final row in gRows.whereType<Map<String, dynamic>>()) {
        final gid = (row['group_id'] ?? '').toString();
        if (gid.isEmpty) continue;
        if (!latestByGroup.containsKey(gid)) {
          latestByGroup[gid] = row;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _directChats
        ..clear()
        ..addAll(latestByUser.values);
      _groupChats
        ..clear()
        ..addAll(groups);
      _groupLatest
        ..clear()
        ..addAll(latestByGroup);
      _loading = false;
    });
  }

  Widget _buildDirectCard(Map<String, dynamic> item) {
    final body = (item['body'] ?? '').toString();
    final created = (item['created_at'] ?? '').toString();
    final sender = (item['sender_id'] ?? '').toString();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final otherName = sender == userId
        ? (item['recipient_name'] ?? '').toString()
        : (item['sender_name'] ?? '').toString();

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
            children: [
              Expanded(
                child: Text(
                  otherName.isEmpty ? _t('Chat', 'Chatt') : otherName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
          if (created.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              created,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> row) {
    final group = row['groups'] as Map<String, dynamic>?;
    final name = (group?['name'] ?? '').toString();
    final id = (group?['id'] ?? '').toString();
    final latest = _groupLatest[id];
    final preview = (latest?['body'] ?? '').toString();
    final created = (latest?['created_at'] ?? '').toString();
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
          Text(
            name.isEmpty ? _t('Group chat', 'Gruppchatt') : name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              preview,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
          if (created.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              created,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Chats', 'Chattar')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
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
                  : _directChats.isEmpty && _groupChats.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _t('No chats yet', 'Inga chattar ännu'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            if (_groupChats.isNotEmpty) ...[
                              Text(
                                _t('Group chats', 'Gruppchattar'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._groupChats.map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: () {
                                      final group =
                                          row['groups'] as Map<String, dynamic>?;
                                      final id =
                                          (group?['id'] ?? '').toString();
                                      final name =
                                          (group?['name'] ?? '').toString();
                                      if (id.isEmpty) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GroupChatScreen(
                                            appState: widget.appState,
                                            groupId: id,
                                            groupName: name,
                                          ),
                                        ),
                                      );
                                    },
                                    child: _buildGroupCard(row),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_directChats.isNotEmpty) ...[
                              Text(
                                _t('Direct chats', 'Direktchattar'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._directChats.map(
                                (row) {
                                  final sender =
                                      (row['sender_id'] ?? '').toString();
                                  final recipient =
                                      (row['recipient_id'] ?? '').toString();
                                  final userId = Supabase
                                          .instance.client.auth.currentUser?.id ??
                                      '';
                                  final otherId =
                                      sender == userId ? recipient : sender;
                                  final otherName = sender == userId
                                      ? (row['recipient_name'] ?? '').toString()
                                      : (row['sender_name'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: InkWell(
                                      onTap: () {
                                        if (otherId.isEmpty) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DirectChatScreen(
                                              appState: widget.appState,
                                              otherUserId: otherId,
                                              otherDisplayName:
                                                  otherName.isEmpty
                                                      ? _t('Chat', 'Chatt')
                                                      : otherName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: _buildDirectCard(row),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }
}
