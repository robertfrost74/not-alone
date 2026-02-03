import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'invites_screen.dart';
import 'request_screen.dart';
import 'welcome_screen.dart';

class HubScreen extends StatefulWidget {
  final AppState appState;

  const HubScreen({
    super.key,
    required this.appState,
  });

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  bool _loading = false;

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(appState: widget.appState),
        ),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading
              ? null
              : () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => WelcomeScreen(appState: widget.appState),
                      ),
                      (route) => false,
                    );
                  }
                },
        ),
        title: Text(_t('Choose next step', 'Välj nästa steg')),
        actions: [
          TextButton(
            onPressed: _loading ? null : _signOut,
            child: Text(_t('Sign out', 'Logga ut')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('What do you want to do now?', 'Vad vill du göra nu?'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestScreen(appState: widget.appState),
                    ),
                  );
                },
                child: Text(_t('Create invite', 'Skapa inbjudan')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvitesScreen(appState: widget.appState),
                    ),
                  );
                },
                child: Text(_t('Browse invites', 'Se inbjudningar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
