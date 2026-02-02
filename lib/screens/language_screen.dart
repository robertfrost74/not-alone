import 'package:flutter/material.dart';
import '../state/app_state.dart';

class LanguageScreen extends StatelessWidget {
  final AppState appState;

  const LanguageScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isSv = appState.locale.languageCode == 'sv';

    return Scaffold(
      appBar: AppBar(title: Text(isSv ? 'Språk' : 'Language')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _LangCard(
              title: 'English',
              subtitle: 'Use the app in English',
              onTap: () {
                appState.setLocale(const Locale('en'));
                Navigator.pushReplacementNamed(context, '/email');
              },
            ),
            const SizedBox(height: 12),
            _LangCard(
              title: 'Svenska',
              subtitle: 'Använd appen på svenska',
              onTap: () {
                appState.setLocale(const Locale('sv'));
                Navigator.pushReplacementNamed(context, '/email');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LangCard({
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