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
      Navigator.pushReplacementNamed(context, '/hub');
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Social',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                isSv
                    ? 'Små steg. Tillsammans.\nFrån ensam → tillsammans på under 60 sekunder.'
                    : 'Small steps. Together.\nFrom alone → together in under 60 seconds.',
                style: const TextStyle(fontSize: 18),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : (isLoggedIn ? _signOut : _showLoginSheet),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLoggedIn ? (isSv ? 'Logga ut' : 'Sign out') : (isSv ? 'Logga in' : 'Login')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _loading ? null : _showLanguageSheet,
                  child: Text(isSv ? 'Byt språk' : 'Language'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
