import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import '../widgets/social_chrome.dart';
import '../services/location_service.dart';

class CreateInviteScreen extends StatefulWidget {
  final AppState appState;

  const CreateInviteScreen({super.key, required this.appState});

  @override
  State<CreateInviteScreen> createState() => _CreateInviteScreenState();
}

class _CreateInviteScreenState extends State<CreateInviteScreen> {
  String _activity = 'walk';
  String _mode = '1to1';
  int? _maxParticipants;
  String _energy = 'medium';
  String _talkLevel = 'low';
  int _duration = 20;
  double _radiusKm = 20;
  late DateTime _meetingTime;
  late TextEditingController _placeController;
  bool _saving = false;

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  @override
  void initState() {
    super.initState();
    _meetingTime = DateTime.now().add(const Duration(minutes: 10));
    _placeController = TextEditingController(text: _defaultPlace(_activity));
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  String _defaultPlace(String activity) {
    if (activity == 'coffee') {
      return _t('Cafe entrance', 'Kafeentre');
    }
    if (activity == 'workout') {
      return _t('Gym entrance', 'Gymentre');
    }
    if (activity == 'lunch') {
      return _t('Restaurant entrance', 'Restaurangentre');
    }
    if (activity == 'dinner') {
      return _t('Dinner spot entrance', 'Middagstalle entre');
    }
    return _t('Start point near you', 'Startpunkt nara dig');
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  Future<void> _pickMeetingTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _meetingTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: _t('Pick a date', 'Valj datum'),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingTime),
      helpText: _t('Pick a time', 'Valj tid'),
    );
    if (pickedTime == null) return;
    if (!mounted) return;

    setState(() {
      _meetingTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    final place = _placeController.text.trim();
    if (place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter a place', 'Ange en plats'))),
      );
      return;
    }
    if (_mode == 'group' && _maxParticipants == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Pick max participants', 'Välj max antal'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final position = await LocationService().getPosition(allowPrompt: true);
      if (position != null) {
        widget.appState.setLocation(
          lat: position.latitude,
          lon: position.longitude,
        );
      }
      final metadataCity =
          (Supabase.instance.client.auth.currentUser?.userMetadata?['city'] ?? '')
              .toString()
              .trim();
      final city =
          widget.appState.city ?? (metadataCity.isEmpty ? null : metadataCity);
      widget.appState.setCity(city);
      await Supabase.instance.client.from('invites').insert({
        'host_user_id': userId,
        'activity': _activity,
        'mode': _mode,
        'max_participants': _mode == 'group' ? _maxParticipants : null,
        'energy': _energy,
        'talk_level': _talkLevel,
        'duration': _duration,
        'meeting_time': _meetingTime.toIso8601String(),
        'place': place,
        'lat': widget.appState.currentLat,
        'lon': widget.appState.currentLon,
        'city': city,
        'radius_km': _radiusKm.round(),
        'status': 'open',
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Create invite', 'Skapa inbjudan')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SocialBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: _t('Activity', 'Aktivitet')),
                  const SizedBox(height: 8),
                  _ChoiceWrap(
                    selected: _activity,
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
                    onChanged: (value) {
                      setState(() {
                        final oldDefault = _defaultPlace(_activity);
                        _activity = value;
                        if (_placeController.text.trim().isEmpty ||
                            _placeController.text.trim() == oldDefault) {
                          _placeController.text = _defaultPlace(value);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: _t('Mode', 'Lage')),
                  const SizedBox(height: 8),
                  _ChoiceWrap(
                    selected: _mode,
                    options: [
                      const _ChoiceOption(value: '1to1', label: '1:1'),
                      _ChoiceOption(
                          value: 'group', label: _t('Group', 'Grupp')),
                    ],
                    onChanged: (value) => setState(() {
                      _mode = value;
                      if (_mode != 'group') _maxParticipants = null;
                    }),
                  ),
                  if (_mode == 'group') ...[
                    const SizedBox(height: 12),
                    _SectionTitle(title: _t('Max participants', 'Max antal')),
                    const SizedBox(height: 8),
                    _ChoiceWrap(
                      selected: (_maxParticipants ?? '').toString(),
                      options: const [
                        _ChoiceOption(value: '2', label: '2'),
                        _ChoiceOption(value: '3', label: '3'),
                        _ChoiceOption(value: '4', label: '4'),
                        _ChoiceOption(value: '6', label: '6'),
                      ],
                      onChanged: (value) =>
                          setState(() => _maxParticipants = int.parse(value)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SectionTitle(title: _t('Energy', 'Energi')),
                  const SizedBox(height: 8),
                  _ChoiceWrap(
                    selected: _energy,
                    options: [
                      _ChoiceOption(value: 'low', label: _t('Low', 'Lag')),
                      _ChoiceOption(
                          value: 'medium', label: _t('Medium', 'Mellan')),
                      _ChoiceOption(value: 'high', label: _t('High', 'Hog')),
                    ],
                    onChanged: (value) => setState(() => _energy = value),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: _t('Talk level', 'Pratniva')),
                  const SizedBox(height: 8),
                  _ChoiceWrap(
                    selected: _talkLevel,
                    options: [
                      _ChoiceOption(value: 'low', label: _t('Quiet', 'Tyst')),
                      _ChoiceOption(
                          value: 'medium', label: _t('Some talk', 'Lite prat')),
                      _ChoiceOption(
                          value: 'high', label: _t('Social', 'Social')),
                    ],
                    onChanged: (value) => setState(() => _talkLevel = value),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: _t('Duration', 'Längd på aktivitet')),
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
                        Text(
                          '$_duration min',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Slider(
                          min: 10,
                          max: 120,
                          divisions: 110,
                          value: _duration.toDouble(),
                          label: '$_duration min',
                          onChanged: (value) =>
                              setState(() => _duration = value.round()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: _t('Radius', 'Avstånd från mig')),
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
                        Text(
                          '${_radiusKm.round()} km',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Slider(
                          min: 1,
                          max: 50,
                          divisions: 49,
                          value: _radiusKm,
                          label: '${_radiusKm.round()} km',
                          onChanged: (value) =>
                              setState(() => _radiusKm = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(title: _t('Meeting time', 'Motestid')),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickMeetingTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_formatDateTime(_meetingTime)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: _t('Meeting place', 'Mötesplats')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _placeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          _t('Type a public place', 'Skriv en offentlig plats'),
                      hintStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving
                          ? _t('Posting...', 'Publicerar...')
                          : _t('Post invite', 'Publicera inbjudan')),
                    ),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _ChoiceOption {
  final String value;
  final String label;

  const _ChoiceOption({required this.value, required this.label});
}

class _ChoiceWrap extends StatelessWidget {
  final List<_ChoiceOption> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
        children: options
          .map(
            (option) => SocialChoiceChip(
              label: option.label,
              selected: option.value == selected,
              onSelected: (_) => onChanged(option.value),
            ),
          )
          .toList(),
    );
  }
}
