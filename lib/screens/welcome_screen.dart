import 'package:flutter/material.dart';
import '../state/app_state.dart';

class WelcomeScreen extends StatelessWidget {
  final AppState appState;

  const WelcomeScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isSv = appState.locale.languageCode == 'sv';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Not Alone',
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
                  onPressed: () => Navigator.pushNamed(context, '/language'),
                  child: Text(isSv ? 'Fortsätt' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}