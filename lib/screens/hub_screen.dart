import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'invites_screen.dart';
import 'profile_screen.dart';
import 'request_screen.dart';
import 'welcome_screen.dart';
import '../widgets/social_chrome.dart';

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

  Future<void> _onMenuSelected(String value) async {
    if (value == 'profile') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(appState: widget.appState),
        ),
      );
      return;
    }
    if (value == 'logout') {
      await _signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text(_t('Choose next step', 'Välj nästa steg')),
          actions: [
            PopupMenuButton<String>(
              enabled: !_loading,
              icon: const Icon(Icons.menu),
              color: const Color(0xFF10201E),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white24),
              ),
              onSelected: _onMenuSelected,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Profile', 'Profil'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _t('Sign out', 'Logga ut'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SocialBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SocialPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RequestScreen(appState: widget.appState),
                            ),
                          );
                        },
                        child: Text(_t('Create invite', 'Skapa inbjudan')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InvitesScreen(appState: widget.appState),
                            ),
                          );
                        },
                        child: Text(_t('Browse invites', 'Se inbjudningar')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
