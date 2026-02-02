import 'package:flutter/material.dart';
import '../state/app_state.dart';

class PhoneScreen extends StatefulWidget {
  final AppState appState;

  const PhoneScreen({super.key, required this.appState});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';

    return Scaffold(
      appBar: AppBar(title: Text(isSv ? 'Verifiera telefon' : 'Verify phone')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSv ? 'Ditt nummer' : 'Your phone number',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: isSv ? '+46 70 123 45 67' : '+1 555 123 4567',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        await Future.delayed(const Duration(milliseconds: 300));
                        setState(() => _loading = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isSv ? 'Nästa: skicka OTP' : 'Next: send OTP')),
                        );
                      },
                child: Text(_loading ? (isSv ? 'Vänta…' : 'Please wait…') : (isSv ? 'Skicka kod' : 'Send code')),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSv ? 'Första träffar sker alltid på offentliga platser.' : 'First meetups are always in public places.',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}