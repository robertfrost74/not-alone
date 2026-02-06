import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'welcome_screen.dart';
import 'invites_screen.dart';

class EnergyScreen extends StatefulWidget {
  final AppState appState;
  const EnergyScreen({super.key, required this.appState});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  bool _loading = false;

  String _t(String en, String sv) => widget.appState.locale.languageCode == 'sv' ? sv : en;

  Future<void> _saveEnergyAndContinue(String energy) async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSv ? 'Inte inloggad' : 'Not signed in')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'language': widget.appState.locale.languageCode,
        'energy': energy,
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvitesScreen(appState: widget.appState),
        ),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSv ? 'Något gick fel' : 'Something went wrong')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen(appState: widget.appState)),
        (route) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSv ? 'Kunde inte logga ut' : 'Could not sign out')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';

    return Scaffold(
      appBar: AppBar(
        title: Text(isSv ? 'Check-in' : 'Check-in'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _signOut,
            child: Text(isSv ? 'Logga ut' : 'Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('How do you feel today?', 'Hur känns det idag?'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _EnergyCard(
              title: _t('Low energy', 'Låg energi'),
              subtitle: _t('Quiet walk / coffee', 'Tyst promenad / kaffe'),
              onTap: _loading ? null : () => _saveEnergyAndContinue('low'),
            ),
            const SizedBox(height: 12),
            _EnergyCard(
              title: _t('Medium', 'Mellan'),
              subtitle: _t('Some talk / simple activity', 'Prata lite / enkel aktivitet'),
              onTap: _loading ? null : () => _saveEnergyAndContinue('medium'),
            ),
            const SizedBox(height: 12),
            _EnergyCard(
              title: _t('High', 'Hög energi'),
              subtitle: _t('Game / event / spontaneous', 'Spel / event / spontant'),
              onTap: _loading ? null : () => _saveEnergyAndContinue('high'),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _EnergyCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
