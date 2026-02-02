import 'dart:async';
import 'package:flutter/material.dart';
import '../state/app_state.dart';

class MeetScreen extends StatefulWidget {
  final AppState appState;
  final int minutes;

  const MeetScreen({super.key, required this.appState, this.minutes = 20});

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  Timer? _timer;
  late int _remainingSeconds;

  String _t(String en, String sv) => widget.appState.locale.languageCode == 'sv' ? sv : en;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.minutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });

      if (_remainingSeconds == 0) {
        _timer?.cancel();
        _showExtendSheet();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Future<void> _showExtendSheet() async {
    if (!mounted) return;
    final isSv = widget.appState.locale.languageCode == 'sv';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSv ? 'Fortsätta?' : 'Extend?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(isSv ? 'Vill ni lägga till 10 minuter?' : 'Want to add 10 more minutes?'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(this.context); // exit meet mode
                        },
                        child: Text(isSv ? 'Avsluta' : 'Finish'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _remainingSeconds = 10 * 60);
                          _timer?.cancel();
                          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
                            if (!mounted) return;
                            setState(() {
                              if (_remainingSeconds > 0) _remainingSeconds--;
                            });
                            if (_remainingSeconds == 0) {
                              _timer?.cancel();
                              _showExtendSheet();
                            }
                          });
                        },
                        child: Text(isSv ? '+10 min' : '+10 min'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';

    return Scaffold(
      appBar: AppBar(
        title: Text(isSv ? 'Möte' : 'Meet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSv ? 'Meet mode' : 'Meet mode',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              _mmss(_remainingSeconds),
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Text(
              isSv
                  ? 'Tryck när du är framme.'
                  : 'Tap when you arrive.',
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isSv ? 'Markerad: Jag är här ✅' : 'Marked: I’m here ✅')),
                  );
                },
                child: Text(isSv ? 'Jag är här' : 'I’m here'),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isSv ? 'Nästa steg: safety share' : 'Next: safety share')),
                );
              },
              child: Text(isSv ? 'Safety' : 'Safety'),
            ),
          ],
        ),
      ),
    );
  }
}