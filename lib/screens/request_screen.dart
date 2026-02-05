import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'match_screen.dart';
import '../widgets/social_chrome.dart';

class RequestScreen extends StatefulWidget {
  final AppState appState;

  const RequestScreen({super.key, required this.appState});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String _activity = 'walk';
  int _participantCount = 1;
  double _durationMin = 20;
  bool _loading = false;

  String _t(String en, String sv) =>
      widget.appState.locale.languageCode == 'sv' ? sv : en;

  Future<void> _submit() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSv ? 'Inte inloggad' : 'Not signed in')),
      );
      return;
    }
    final mode = _participantCount == 1 ? 'one_to_one' : 'group';

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.from('session_requests').insert({
        'user_id': user.id,
        'activity': _activity,
        'mode': mode,
        'duration_min': _durationMin.round(),
        'radius_m': 1000,
        'energy': 'medium',
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MatchScreen(
            appState: widget.appState,
            selectedActivity: _activity,
            selectedDuration: _durationMin.round(),
            selectedMode: mode,
            selectedEnergy: 'medium',
            selectedMaxParticipants: mode == 'group' ? _participantCount : null,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isSv ? 'Något gick fel' : 'Something went wrong')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isSv ? 'Välj aktivitet' : 'Choose activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SocialBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SocialPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('What do you want to do?', 'Vad vill du göra?'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _Segment(title: _t('Activity', 'Aktivitet')),
                  const SizedBox(height: 8),
                  _ChoiceRow(
                    options: [
                      _ChoiceOption(
                          value: 'walk', label: _t('Walk', 'Promenad')),
                      _ChoiceOption(
                          value: 'workout', label: _t('Workout', 'Träna')),
                      _ChoiceOption(value: 'coffee', label: _t('Fika', 'Fika')),
                      _ChoiceOption(
                          value: 'lunch', label: _t('Lunch', 'Luncha')),
                      _ChoiceOption(
                          value: 'dinner', label: _t('Dinner', 'Middag')),
                    ],
                    selected: _activity,
                    onChanged: (v) => setState(() => _activity = v),
                  ),
                  const SizedBox(height: 18),
                  _Segment(title: _t('Max participants', 'Max antal')),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            _participantCount.toString(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            padding: EdgeInsets.zero,
                          ),
                          child: Slider(
                            min: 1,
                            max: 10,
                            divisions: 9,
                            value: _participantCount.toDouble(),
                            label: _participantCount.toString(),
                            onChanged: (v) =>
                                setState(() => _participantCount = v.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Segment(title: _t('Duration', 'Längd')),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            '${_durationMin.round()} min',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            padding: EdgeInsets.zero,
                          ),
                          child: Slider(
                            min: 10,
                            max: 120,
                            divisions: 110,
                            value: _durationMin,
                            label: '${_durationMin.round()} min',
                            onChanged: (v) => setState(() => _durationMin = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading
                          ? _t('Saving…', 'Sparar…')
                          : _t('Continue', 'Fortsätt')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'We’ll only suggest public places for first meetups.',
                      'Vi föreslår bara offentliga platser för första träffar.',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String title;
  const _Segment({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
  }
}

class _ChoiceOption {
  final String value;
  final String label;
  const _ChoiceOption({required this.value, required this.label});
}

class _ChoiceRow extends StatelessWidget {
  final List<_ChoiceOption> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((o) {
        final isSelected = o.value == selected;
        return ChoiceChip(
          label: Text(o.label),
          selected: isSelected,
          onSelected: (_) => onChanged(o.value),
        );
      }).toList(),
    );
  }
}
