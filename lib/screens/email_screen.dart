import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  bool _loading = false;

  Future<void> _devLoginAnonymous() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInAnonymously();

      final session = res.session;
      final token = session?.accessToken;

      // 🔴 DETTA ÄR DET VIKTIGA
      debugPrint('ACCESS_TOKEN=$token');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/checkin');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Not Alone')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Dev login (anonymous)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _devLoginAnonymous,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Logga in (Dev)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}