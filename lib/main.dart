import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'state/app_state.dart';
import 'screens/welcome_screen.dart';
import 'screens/language_screen.dart';
import 'screens/email_screen.dart';
import 'screens/energy_screen.dart';
import 'screens/request_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  debugPrint('SUPABASE_URL=$supabaseUrl');
  debugPrint('SUPABASE_ANON_KEY length=${supabaseAnonKey.length}');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const NotAloneApp());
}

class NotAloneApp extends StatefulWidget {
  const NotAloneApp({super.key});

  @override
  State<NotAloneApp> createState() => _NotAloneAppState();
}

class _NotAloneAppState extends State<NotAloneApp> {
  final _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        final user = Supabase.instance.client.auth.currentUser;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Not Alone',
          theme: ThemeData(useMaterial3: true),
          locale: _appState.locale,
          routes: {
            '/': (_) => user == null
                ? WelcomeScreen(appState: _appState)
                : EnergyScreen(appState: _appState),
            '/language': (_) => LanguageScreen(appState: _appState),
            '/email': (_) => EmailScreen(appState: _appState),
            '/energy': (_) => EnergyScreen(appState: _appState),

            // Request screen is opened via MaterialPageRoute (we pass energy),
            // but we keep a route placeholder in case you want it later.
            '/request': (_) => RequestScreen(appState: _appState, energy: 'medium'),
          },
        );
      },
    );
  }
}