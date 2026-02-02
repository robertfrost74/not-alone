import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class MatchScreen extends StatefulWidget {
  final AppState appState;

  const MatchScreen({super.key, required this.appState});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool _loading = false;

  String _t(String en, String sv) => widget.appState.locale.languageCode == 'sv' ? sv : en;

  Future<List<String>> _fetchInvites({
    required String activity,
    required int duration,
  }) async {
    final lang = widget.appState.locale.languageCode;

    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (anonKey.isEmpty) {
      throw Exception('Missing SUPABASE_ANON_KEY (dart-define).');
    }

    final res = await Supabase.instance.client.functions.invoke(
      'invite-writer',
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json',
      },
      body: {
        'language': lang,
        'activity': activity, // walk|coffee|codo
        'duration': duration,
      },
    );

    final data = res.data;
    if (data == null) throw Exception('No data from function');

    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map<String, dynamic>) throw Exception('Unexpected response format');

    if (decoded['ok'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Function failed');
    }

    final suggestions = decoded['suggestions'];
    if (suggestions is! List) throw Exception('No suggestions returned');

    return suggestions.map((e) => e.toString()).toList();
  }

  Future<void> _saveInvite({
    required String activity,
    required int duration,
    required String language,
    required String text,
  }) async {
    await Supabase.instance.client.from('sent_invites').insert({
      'user_id': Supabase.instance.client.auth.currentUser?.id,
      'activity': activity,
      'duration': duration,
      'language': language,
      'invite_text': text,
    });
  }

  Future<void> _onInvitePressed({
    required String activity,
    required int duration,
  }) async {
    setState(() => _loading = true);

    try {
      final suggestions = await _fetchInvites(activity: activity, duration: duration);
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          final isSv = widget.appState.locale.languageCode == 'sv';
          final lang = widget.appState.locale.languageCode;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSv ? 'Välj en inbjudan' : 'Pick an invite',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...suggestions.map(
                    (s) => _InviteTile(
                      text: s,
                      activity: activity,
                      duration: duration,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: s));

                        await _saveInvite(
                          activity: activity,
                          duration: duration,
                          language: lang,
                          text: s,
                        );

                        if (!mounted) return;

                        // Close bottom sheet and open Meet mode
                        Navigator.pop(context);
                        Navigator.pushNamed(this.context, '/meet');
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSv
                        ? 'Nästa steg: Meet mode (Jag är här + timer).'
                        : 'Next: Meet mode (I’m here + timer).',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Fel:', 'Fel:')} $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = [
      _MatchCardData(
        vibe: _t('Quiet walk, no pressure', 'Lugn promenad, inga krav'),
        distance: _t('650 m away', '650 m bort'),
        reliability: _t('On time usually', 'Brukar vara i tid'),
        activity: 'walk',
        duration: 20,
      ),
      _MatchCardData(
        vibe: _t('Coffee + light chat', 'Kaffe + lite prat'),
        distance: _t('1.2 km away', '1,2 km bort'),
        reliability: _t('Friendly & calm', 'Vänlig & lugn'),
        activity: 'coffee',
        duration: 30,
      ),
      _MatchCardData(
        vibe: _t('Co-do: read/work quietly', 'Co-do: läsa/jobba tyst'),
        distance: _t('900 m away', '900 m bort'),
        reliability: _t('Prefers quiet', 'Föredrar tyst'),
        activity: 'codo',
        duration: 60,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_t('Matches', 'Matchningar'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('People nearby with the same vibe', 'Personer nära med samma vibe'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final m = matches[index];
                  return _MatchCard(
                    vibe: m.vibe,
                    distance: m.distance,
                    reliability: m.reliability,
                    buttonText: _t('Send invite', 'Skicka inbjudan'),
                    onInvite: _loading ? null : () => _onInvitePressed(activity: m.activity, duration: m.duration),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCardData {
  final String vibe;
  final String distance;
  final String reliability;
  final String activity;
  final int duration;

  const _MatchCardData({
    required this.vibe,
    required this.distance,
    required this.reliability,
    required this.activity,
    required this.duration,
  });
}

class _MatchCard extends StatelessWidget {
  final String vibe;
  final String distance;
  final String reliability;
  final String buttonText;
  final VoidCallback? onInvite;

  const _MatchCard({
    required this.vibe,
    required this.distance,
    required this.reliability,
    required this.buttonText,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vibe, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(distance, style: const TextStyle(color: Colors.black54))),
              Expanded(child: Text(reliability, style: const TextStyle(color: Colors.black54))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onInvite,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  final String text;
  final String activity;
  final int duration;
  final Future<void> Function() onTap;

  const _InviteTile({
    required this.text,
    required this.activity,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async => onTap(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}