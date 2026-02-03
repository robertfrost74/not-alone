import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'state/app_state.dart';
import 'screens/welcome_screen.dart';
import 'screens/language_screen.dart';
import 'screens/email_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/request_screen.dart';
import 'screens/meet_screen.dart';
import 'screens/invites_screen.dart';

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
          title: 'Social',
          theme: ThemeData(
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(),
            primaryTextTheme: GoogleFonts.interTextTheme(),
          ),
          locale: _appState.locale,
          routes: {
            '/': (_) => user == null
                ? WelcomeScreen(appState: _appState)
                : HubScreen(appState: _appState),
            '/language': (_) => LanguageScreen(appState: _appState),
            '/email': (_) => EmailScreen(appState: _appState),
            '/hub': (_) => HubScreen(appState: _appState),
            '/invites': (_) => InvitesScreen(appState: _appState),

            // Request screen is opened via MaterialPageRoute (we pass energy),
            // but we keep a route placeholder in case you want it later.
            '/request': (_) => RequestScreen(appState: _appState),
          },
          onGenerateRoute: (settings) {
            if (settings.name != '/meet') return null;

            final args = settings.arguments;
            final data = args is Map ? args : const {};

            DateTime? meetingTime;
            final rawMeetingTime = data['meeting_time'];
            if (rawMeetingTime is DateTime) {
              meetingTime = rawMeetingTime;
            } else if (rawMeetingTime is String && rawMeetingTime.isNotEmpty) {
              meetingTime = DateTime.tryParse(rawMeetingTime);
            }

            DateTime? createdAt;
            final rawCreatedAt = data['created_at'];
            if (rawCreatedAt is DateTime) {
              createdAt = rawCreatedAt;
            } else if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
              createdAt = DateTime.tryParse(rawCreatedAt);
            }

            final rawDuration = data['duration'];
            int duration = 20;
            if (rawDuration is int) {
              duration = rawDuration;
            } else if (rawDuration != null) {
              duration = int.tryParse(rawDuration.toString()) ?? 20;
            }

            return MaterialPageRoute(
              builder: (_) => MeetScreen(
                appState: _appState,
                minutes: duration,
                inviteId: data['invite_id']?.toString(),
                inviteMemberId: data['invite_member_id']?.toString(),
                initialMeetingTime: meetingTime,
                initialCreatedAt: createdAt,
                initialPlace: data['place']?.toString(),
              ),
            );
          },
        );
      },
    );
  }
}
