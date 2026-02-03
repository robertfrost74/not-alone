import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'invites_screen.dart';
import 'request_screen.dart';

class HubScreen extends StatelessWidget {
  final AppState appState;
  final String energy;

  const HubScreen({
    super.key,
    required this.appState,
    required this.energy,
  });

  bool get isSv => appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('Choose next step', 'Välj nästa steg'))),
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
                      builder: (_) => RequestScreen(appState: appState, energy: energy),
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
                      builder: (_) => InvitesScreen(appState: appState),
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

