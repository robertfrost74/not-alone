import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';

class DirectChatScreen extends StatefulWidget {
  final AppState appState;
  final String otherUserId;
  final String otherDisplayName;

  const DirectChatScreen({
    super.key,
    required this.appState,
    required this.otherUserId,
    required this.otherDisplayName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channelSent;
  RealtimeChannel? _channelReceived;

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _channelSent?.unsubscribe();
    _channelReceived?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _channelSent = supabase.channel('dm_sent_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'direct_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: user.id,
        ),
        callback: (_) => _loadMessages(),
      )
      ..subscribe();

    _channelReceived = supabase.channel('dm_recv_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'direct_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: user.id,
        ),
        callback: (_) => _loadMessages(),
      )
      ..subscribe();
  }

  Future<void> _loadMessages() async {
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

    final filtered = all.where((m) {
      final sender = (m['sender_id'] ?? '').toString();
      final recipient = (m['recipient_id'] ?? '').toString();
      return (sender == widget.otherUserId && recipient == user.id) ||
          (sender == user.id && recipient == widget.otherUserId);
    }).toList();

    filtered.sort((a, b) {
      final ad = DateTime.tryParse((a['created_at'] ?? '').toString());
      final bd = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1;
      if (bd == null) return 1;
      return ad.compareTo(bd);
    });

    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(filtered);
      _loading = false;
    });
  }

  String _displayNameFor(User user) {
    final metadata = user.userMetadata ?? const {};
    final username = (metadata['username'] ?? '').toString().trim();
    final fullName = (metadata['full_name'] ?? '').toString().trim();
    final email = (user.email ?? '').trim();
    if (username.isNotEmpty) return username;
    if (fullName.isNotEmpty) return fullName;
    return email.isNotEmpty ? email : user.id;
  }

  Future<bool> _isBlocked(String me, String other) async {
    final supabase = Supabase.instance.client;
    final blockedByOther = await supabase
        .from('user_blocks')
        .select('id')
        .match({'blocker_id': other, 'blocked_id': me});
    if (blockedByOther.isNotEmpty) return true;
    final blockedByMe = await supabase
        .from('user_blocks')
        .select('id')
        .match({'blocker_id': me, 'blocked_id': other});
    if (blockedByMe.isNotEmpty) return true;
    return false;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isBlocked = await _isBlocked(user.id, widget.otherUserId);
    if (isBlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('Messaging is blocked.', 'Meddelanden är blockerade.'),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _sending = true);
    final optimistic = {
      'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': user.id,
      'recipient_id': widget.otherUserId,
      'sender_name': _displayNameFor(user),
      'recipient_name': widget.otherDisplayName,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages.add(optimistic);
    });
    try {
      await supabase.from('direct_messages').insert({
        'sender_id': user.id,
        'recipient_id': widget.otherUserId,
        'sender_name': _displayNameFor(user),
        'recipient_name': widget.otherDisplayName,
        'body': text,
      });
      _messageController.clear();
      await _loadMessages();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTimestamp(String value) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _messageBubble(Map<String, dynamic> msg) {
    final body = (msg['body'] ?? '').toString();
    final sender = (msg['sender_name'] ?? '').toString();
    final created = (msg['created_at'] ?? '').toString();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = (msg['sender_id'] ?? '').toString() == userId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF2DD4CF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              sender.isEmpty ? _t('Member', 'Medlem') : sender,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: isMe ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: isMe ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(created),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
              textAlign: isMe ? TextAlign.right : TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.otherDisplayName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SocialBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: Column(
                children: [
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _messages.length,
                            itemBuilder: (context, index) =>
                                _messageBubble(_messages[index]),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText:
                                _t('Write a message', 'Skriv ett meddelande'),
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
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _sending ? null : _sendMessage,
                          child: Text(_t('Send', 'Skicka')),
                        ),
                      ),
                    ],
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
