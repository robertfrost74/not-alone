import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'match_screen.dart';

class RequestScreen extends StatefulWidget {
  final AppState appState;
  final String energy;

  const RequestScreen({super.key, required this.appState, required this.energy});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String _activity = 'walk';
  String _mode = 'one_to_one';
  int? _maxParticipants;
  double _durationMin = 20;
  bool _loading = false;

  String _t(String en, String sv) => widget.appState.locale.languageCode == 'sv' ? sv : en;

  Future<void> _submit() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSv ? 'Inte inloggad' : 'Not signed in')),
      );
      return;
    }
    if (_mode == 'group' && _maxParticipants == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSv ? 'Välj max antal för grupp' : 'Pick max participants for group')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.from('session_requests').insert({
        'user_id': user.id,
        'activity': _activity,
        'mode': _mode,
        'duration_min': _durationMin.round(),
        'radius_m': 1000,
        'energy': widget.energy,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MatchScreen(
            appState: widget.appState,
            selectedActivity: _activity,
            selectedDuration: _durationMin.round(),
            selectedMode: _mode,
            selectedEnergy: widget.energy,
            selectedMaxParticipants: _maxParticipants,
          ),
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

  @override
  Widget build(BuildContext context) {
    final isSv = widget.appState.locale.languageCode == 'sv';

    return Scaffold(
      appBar: AppBar(title: Text(isSv ? 'Välj aktivitet' : 'Choose activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('What do you want to do?', 'Vad vill du göra?'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            const _Segment(title: 'Activity'),
            const SizedBox(height: 8),
            _ChoiceRow(
              options: [
                _ChoiceOption(value: 'walk', label: _t('Walk', 'Promenad')),
                _ChoiceOption(value: 'workout', label: _t('Workout', 'Träna')),
                _ChoiceOption(value: 'coffee', label: _t('Fika', 'Fika')),
                _ChoiceOption(value: 'lunch', label: _t('Lunch', 'Luncha')),
                _ChoiceOption(value: 'dinner', label: _t('Dinner', 'Middag')),
              ],
              selected: _activity,
              onChanged: (v) => setState(() => _activity = v),
            ),

            const SizedBox(height: 18),

            _Segment(title: _t('Mode', 'Läge')),
            const SizedBox(height: 8),
            _ChoiceRow(
              options: [
                _ChoiceOption(value: 'one_to_one', label: _t('1:1', '1:1')),
                _ChoiceOption(value: 'group', label: _t('Group', 'Grupp')),
              ],
              selected: _mode,
              onChanged: (v) => setState(() {
                _mode = v;
                if (_mode != 'group') _maxParticipants = null;
              }),
            ),

            if (_mode == 'group') ...[
              const SizedBox(height: 12),
              _Segment(title: _t('Max participants', 'Max antal')),
              const SizedBox(height: 8),
              _ChoiceRow(
                options: const [
                  _ChoiceOption(value: '2', label: '2'),
                  _ChoiceOption(value: '3', label: '3'),
                  _ChoiceOption(value: '4', label: '4'),
                  _ChoiceOption(value: '6', label: '6'),
                ],
                selected: (_maxParticipants ?? '').toString(),
                onChanged: (v) => setState(() => _maxParticipants = int.parse(v)),
              ),
            ],

            const SizedBox(height: 18),

            _Segment(title: _t('Duration', 'Längd')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_durationMin.round()} min',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    min: 10,
                    max: 120,
                    divisions: 110,
                    value: _durationMin,
                    label: '${_durationMin.round()} min',
                    onChanged: (v) => setState(() => _durationMin = v),
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
                child: Text(_loading ? _t('Saving…', 'Sparar…') : _t('Continue', 'Fortsätt')),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              _t(
                'We’ll only suggest public places for first meetups.',
                'Vi föreslår bara offentliga platser för första träffar.',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
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
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
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
