import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class WelcomeScreen extends StatefulWidget {
  final AppState appState;

  const WelcomeScreen({super.key, required this.appState});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;

  Future<void> _showLanguageSheet() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isSv ? 'Välj språk' : 'Choose language',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    widget.appState.setLocale(const Locale('en'));
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('English'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    widget.appState.setLocale(const Locale('sv'));
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Svenska'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLoginSheet() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isSv ? 'Logga in' : 'Login',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _devLoginAnonymous();
                          },
                    child: Text(isSv ? 'Logga in (Dev)' : 'Login (Dev)'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _devLoginAnonymous() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInAnonymously();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/hub', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.appState.locale.languageCode == 'sv' ? 'Utloggad' : 'Signed out')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final subtitle = isSv
        ? 'Små steg. Tillsammans.\nFrån ensam till tillsammans på under 60 sekunder.'
        : 'Small steps. Together.\nFrom alone to together in under 60 seconds.';

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF6FF),
                  Color(0xFFE8FFF5),
                  Color(0xFFFFF5E8),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.65, -0.8),
                radius: 1.15,
                colors: [
                  Color(0x66FFFFFF),
                  Color(0x00FFFFFF),
                ],
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.24),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 260,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withOpacity(0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Social',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _loading ? null : _showLanguageSheet,
                        child: Text(isSv ? 'Svenska' : 'English'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 56),
                        const Text(
                          'Social',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isSv ? 'Möt någon. Gör något. Må bättre.' : 'Meet someone. Do something. Feel better.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.65),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _loading ? null : (isLoggedIn ? _signOut : _showLoginSheet),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        isLoggedIn ? (isSv ? 'Logga ut' : 'Sign out') : (isSv ? 'Logga in' : 'Login'),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Text(
                    '© 2026 Social',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
