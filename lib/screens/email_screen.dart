import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class EmailScreen extends StatefulWidget {
  final AppState appState;
  const EmailScreen({super.key, required this.appState});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  bool _loading = false;

  String _t(String en, String sv) => widget.appState.locale.languageCode == 'sv' ? sv : en;

  Future<void> _devLoginAnonymous() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInAnonymously();
      final token = res.session?.accessToken;

      // ✅ This is what we need for curl
      debugPrint('ACCESS_TOKEN=$token');

      if (!mounted) return;

      // Your routes use '/energy' in main.dart, so go there.
      Navigator.pushReplacementNamed(context, '/energy');
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';

    return Scaffold(
      appBar: AppBar(title: const Text('Not Alone')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Dev login (anonymous)', 'Dev login (anonymt)'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _devLoginAnonymous,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isSv ? 'Logga in (Dev)' : 'Login (Dev)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}