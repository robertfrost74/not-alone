import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/social_chrome.dart';

class RequestScreen extends StatefulWidget {
  final AppState appState;

  const RequestScreen({super.key, required this.appState});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String _activity = 'walk';
  String _customActivity = '';
  int _participantCount = 1;
  double _durationMin = 20;
  double _radiusKm = 3;
  RangeValues _ageRange = const RangeValues(16, 120);
  String _targetGender = 'all'; // all | male | female
  bool _loading = false;
  DateTime? _inviteMeetingTime;
  late TextEditingController _invitePlaceController;
  static const double _sliderTrackInset = 12;
  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _groupsLoading = false;
  List<_GroupOption> _groups = const [];
  bool _groupRequired = false;

  @override
  void initState() {
    super.initState();
    _invitePlaceController = TextEditingController();
  }

  @override
  void dispose() {
    _invitePlaceController.dispose();
    super.dispose();
  }

  String _t(String en, String sv) =>
      widget.appState.locale.languageCode == 'sv' ? sv : en;

  String _activityLabel(String activity) {
    switch (activity) {
      case 'walk':
        return _t('Walk', 'Promenad');
      case 'coffee':
        return _t('Fika', 'Fika');
      case 'workout':
        return _t('Workout', 'Träna');
      case 'lunch':
        return _t('Lunch', 'Lunch');
      case 'dinner':
        return _t('Dinner', 'Middag');
      case 'custom':
        return _customActivity.trim().isEmpty
            ? _t('Other', 'Annat')
            : _customActivity.trim();
      default:
        return activity;
    }
  }

  Future<String?> _showCustomActivityDialog(bool isSv) async {
    var tempValue = _customActivity;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return SocialDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          title: Text(isSv ? 'Ange aktivitet' : 'Enter activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: tempValue,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isSv ? 'Skriv aktivitet' : 'Type activity',
                  hintStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) => tempValue = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(isSv ? 'Avbryt' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, tempValue.trim()),
              child: Text(isSv ? 'Spara' : 'Save'),
            ),
          ],
        );
      },
    );
    return result;
  }

  String _modeLabel(String mode) {
    if (mode == 'group') return _t('Group', 'Grupp');
    return _t('1:1', '1:1');
  }

  String _targetGenderLabel(String value) {
    switch (value) {
      case 'male':
        return _t('Men', 'Män');
      case 'female':
        return _t('Women', 'Kvinnor');
      default:
        return _t('All', 'Alla');
    }
  }

  Future<void> _loadUserGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _groups = const [];
      return;
    }

    setState(() => _groupsLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('group_members')
          .select('group_id, groups ( id, name )')
          .match({'user_id': userId});
      if (rows is! List) {
        _groups = const [];
        return;
      }
      final seen = <String>{};
      final items = <_GroupOption>[];
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final group = row['groups'] as Map<String, dynamic>?;
        if (group == null) continue;
        final id = group['id']?.toString() ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        items.add(
          _GroupOption(
            id: id,
            name: (group['name'] ?? '').toString(),
          ),
        );
      }
      _groups = items;
    } finally {
      if (mounted) setState(() => _groupsLoading = false);
    }
  }

  Future<void> _pickGroup() async {
    setState(() => _groupRequired = true);
    if (_groups.isEmpty) {
      await _loadUserGroups();
    }
    if (!mounted) return;

    String? tempSelected = _selectedGroupId;
    String? tempName = _selectedGroupName;

    bool showError = false;
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return SocialDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          title: Text(
              _t('Choose group', 'Välj grupp')),
          content: _groupsLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _groups.isEmpty
                  ? Text(
                      _t('No groups yet', 'Inga grupper ännu'),
                      style: const TextStyle(color: Colors.white70),
                    )
                  : StatefulBuilder(
                      builder: (context, setInnerState) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            unselectedWidgetColor: Colors.white60,
                            radioTheme: RadioThemeData(
                              fillColor: WidgetStateProperty.resolveWith<Color>(
                                (states) => states.contains(WidgetState.selected)
                                    ? const Color(0xFF2DD4CF)
                                    : Colors.white60,
                              ),
                            ),
                          ),
                          child: ListTileTheme(
                            textColor: Colors.white,
                            iconColor: Colors.white70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ..._groups.map(
                                  (g) => RadioListTile<String?>(
                                    value: g.id,
                                    groupValue: tempSelected,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: const Color(0xFF2DD4CF),
                                    title: Text(
                                      g.name.isEmpty
                                          ? _t('Unnamed group', 'Grupp utan namn')
                                          : g.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onChanged: (v) {
                                      setInnerState(() {
                                        tempSelected = v;
                                        tempName = g.name;
                                        showError = false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (showError)
                                      Text(
                                        _t(
                                          'Pick a group first',
                                          'Välj grupp först',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, null),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(_t('Cancel', 'Avbryt')),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton(
                                      onPressed: () {
                                        if (tempSelected == null) {
                                          setInnerState(() => showError = true);
                                          return;
                                        }
                                        Navigator.pop(dialogContext, tempSelected);
                                      },
                                      child: Text(_t('Save', 'Spara')),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          actions: const [],
        );
      },
    );

    if (!mounted) return;
    if (result == null && tempSelected != null) {
      // User cancelled; keep previous selection.
      return;
    }
    setState(() {
      _selectedGroupId = result;
      _selectedGroupName = result == null
          ? null
          : tempName ??
              _groups.firstWhere(
                (g) => g.id == result,
                orElse: () => const _GroupOption(id: '', name: ''),
              ).name;
    });
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  Future<void> _pickInviteMeetingTime() async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final now = DateTime.now();
    final initialMeetingTime =
        _inviteMeetingTime ?? now.add(const Duration(minutes: 10));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialMeetingTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: isSv ? 'Välj datum' : 'Pick a date',
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialMeetingTime),
      helpText: isSv ? 'Välj tid' : 'Pick a time',
    );
    if (pickedTime == null) return;

    setState(() {
      _inviteMeetingTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<bool> _showInviteConfirmModal({
    required String activity,
    required int duration,
    required DateTime meetingTime,
    required String place,
    required String mode,
    required int? maxParticipants,
    required String? groupName,
  }) async {
    final isSv = widget.appState.locale.languageCode == 'sv';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return SocialDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          title: Text(isSv ? 'Godkänn inbjudan' : 'Confirm invite'),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${isSv ? 'Aktivitet' : 'Activity'}: ${_activityLabel(activity)}'),
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Tidpunkt' : 'Time'}: ${_formatDateTime(meetingTime)}'),
                const SizedBox(height: 6),
                Text('${isSv ? 'Mötesplats' : 'Meeting place'}: $place'),
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Längd' : 'Duration'}: $duration ${isSv ? 'min' : 'min'}'),
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Antal' : 'Mode'}: ${_modeLabel(mode)}'),
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Ålders spann' : 'Age range'}: ${_ageRange.start.round()} - ${_ageRange.end.round()}'),
                const SizedBox(height: 6),
              Text(
                groupName != null && groupName.trim().isNotEmpty
                    ? '${isSv ? 'Visa för' : 'Show for'}: ${_t('Group', 'Grupp')}'
                    : '${isSv ? 'Visa för' : 'Show for'}: ${_targetGenderLabel(_targetGender)}',
              ),
              if (groupName != null && groupName.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Grupp' : 'Group'}: $groupName'),
              ],
              if (mode == 'group' && maxParticipants != null) ...[
                const SizedBox(height: 6),
                Text(
                    '${isSv ? 'Max antal' : 'Max participants'}: $maxParticipants'),
              ],
              ],
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isSv ? 'Avbryt' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isSv ? 'Godkänn' : 'Approve'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<String?> _createOpenInvite({
    required String activity,
    required int duration,
    required DateTime meetingTime,
    required String place,
    required String mode,
    required int? maxParticipants,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final data = await Supabase.instance.client
        .from('invites')
        .insert({
          'host_user_id': userId,
          'activity': activity,
          'mode': mode,
          'max_participants': mode == 'group' ? maxParticipants : null,
          'energy': 'medium',
          'talk_level': 'low',
          'duration': duration,
          'meeting_time': meetingTime.toIso8601String(),
          'place': place,
          'age_min': _ageRange.start.round(),
          'age_max': _ageRange.end.round(),
          'target_gender': _targetGender,
          'group_id': _selectedGroupId,
          'status': 'open',
        })
        .select('id')
        .single();

    return data['id']?.toString();
  }

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
    final activityValue =
        _activity == 'custom' ? _customActivity.trim() : _activity;
    final missing = <String>[];
    if (_inviteMeetingTime == null) {
      missing.add(isSv ? 'Tid' : 'Time');
    }
    final place = _invitePlaceController.text.trim();
    if (place.isEmpty) {
      missing.add(isSv ? 'Mötesplats' : 'Meeting place');
    }
    if (activityValue.isEmpty) {
      missing.add(isSv ? 'Aktivitet' : 'Activity');
    }
    if (_groupRequired && _selectedGroupId == null) {
      missing.add(isSv ? 'Grupp' : 'Group');
    }
    if (missing.isNotEmpty) {
      final label = isSv ? 'Saknas' : 'Missing';
      final message = '$label: ${missing.join(', ')}';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return SocialDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
            title: Text(isSv ? 'Fyll i' : 'Complete'),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(isSv ? 'Okej' : 'OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    final meetingTime = _inviteMeetingTime!;

    setState(() => _loading = true);

    try {
      final approved = await _showInviteConfirmModal(
        activity: activityValue,
        duration: _durationMin.round(),
        meetingTime: meetingTime,
        place: place,
        mode: mode,
        maxParticipants: mode == 'group' ? _participantCount : null,
        groupName: _selectedGroupName,
      );
      if (!approved || !mounted) return;

      await _createOpenInvite(
        activity: activityValue,
        duration: _durationMin.round(),
        meetingTime: meetingTime,
        place: place,
        mode: mode,
        maxParticipants: mode == 'group' ? _participantCount : null,
      );

      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/invites', (route) => false);
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
    final customLabel =
        _customActivity.trim().isEmpty ? _t('Other', 'Annat') : _customActivity.trim();
    final activityValue =
        _activity == 'custom' ? _customActivity.trim() : _activity;
    final hasPlace = _invitePlaceController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isSv ? 'Skapa inbjudan' : 'Create invite'),
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
                  _Segment(title: _t('Time', 'Tid')),
                  const SizedBox(height: 8),
                  _InfoEditRow(
                    value: _inviteMeetingTime == null
                        ? _t('Pick meeting time', 'Välj tidpunkt')
                        : _formatDateTime(_inviteMeetingTime!),
                    onTap: _pickInviteMeetingTime,
                  ),
                  const SizedBox(height: 18),
                  _Segment(title: _t('Meeting place', 'Mötesplats')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _invitePlaceController,
                    onChanged: (_) {
                      if (mounted) setState(() {});
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _t('Enter meeting place', 'Skriv in mötesplats'),
                      hintStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
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
                      _ChoiceOption(value: 'custom', label: customLabel),
                    ],
                    selected: _activity,
                    onChanged: (v) async {
                      if (v != 'custom') {
                        setState(() => _activity = v);
                        return;
                      }

                      final previous = _activity;
                      final result = await _showCustomActivityDialog(isSv);
                      if (!mounted) return;
                      if (result == null || result.trim().isEmpty) {
                        setState(() => _activity = previous);
                        return;
                      }
                      setState(() {
                        _customActivity = result.trim();
                        _activity = 'custom';
                      });
                    },
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
                            trackShape: const _FixedTrackShape(
                              horizontalPadding: _sliderTrackInset,
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                          child: Slider(
                            min: 1,
                            max: 20,
                            divisions: 19,
                            value: _participantCount.toDouble().clamp(1, 20),
                            label: _participantCount.toString(),
                            onChanged: (v) =>
                                setState(() => _participantCount = v.round()),
                          ),
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
                            trackShape: const _FixedTrackShape(
                              horizontalPadding: _sliderTrackInset,
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Slider(
                            min: 10,
                            max: 180,
                            divisions: 170,
                            value: _durationMin.clamp(10, 180),
                            label: '${_durationMin.round()} min',
                            onChanged: (v) => setState(() => _durationMin = v),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Segment(title: _t('Age range', 'Ålders spann')),
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
                            '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            padding: EdgeInsets.zero,
                            trackShape: const _FixedTrackShape(
                              horizontalPadding: _sliderTrackInset,
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: RangeSlider(
                              min: 16,
                              max: 120,
                              divisions: 104,
                              values: _ageRange,
                              labels: RangeLabels(
                                _ageRange.start.round().toString(),
                                _ageRange.end.round().toString(),
                              ),
                              onChanged: (v) => setState(() => _ageRange = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Segment(title: _t('Radius', 'Radie')),
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
                            '${_radiusKm.round()} km',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            padding: EdgeInsets.zero,
                            trackShape: const _FixedTrackShape(
                              horizontalPadding: _sliderTrackInset,
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Slider(
                              min: 1,
                              max: 10,
                              divisions: 9,
                              value: _radiusKm,
                              label: '${_radiusKm.round()} km',
                              onChanged: (v) => setState(() => _radiusKm = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Segment(title: _t('Show invite for', 'Visa inbjudan för')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SocialChoiceChip(
                        label: _t('All', 'Alla'),
                        selected:
                            _selectedGroupId == null && _targetGender == 'all',
                        onSelected: (_) => setState(() {
                          _targetGender = 'all';
                          _selectedGroupId = null;
                          _selectedGroupName = null;
                          _groupRequired = false;
                        }),
                      ),
                      SocialChoiceChip(
                        label: _t('Men', 'Män'),
                        selected:
                            _selectedGroupId == null && _targetGender == 'male',
                        onSelected: (_) => setState(() {
                          _targetGender = 'male';
                          _selectedGroupId = null;
                          _selectedGroupName = null;
                          _groupRequired = false;
                        }),
                      ),
                      SocialChoiceChip(
                        label: _t('Women', 'Kvinnor'),
                        selected: _selectedGroupId == null &&
                            _targetGender == 'female',
                        onSelected: (_) => setState(() {
                          _targetGender = 'female';
                          _selectedGroupId = null;
                          _selectedGroupName = null;
                          _groupRequired = false;
                        }),
                      ),
                      SocialChoiceChip(
                        label: _t('Group', 'Grupp'),
                        selected: _selectedGroupId != null,
                        onSelected: (_) {
                          setState(() {
                            _targetGender = 'all';
                          });
                          _pickGroup();
                        },
                      ),
                    ],
                  ),
                  if (_selectedGroupName != null &&
                      _selectedGroupName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _selectedGroupName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _t('Only members will see this invite', 'Endast medlemmar ser inbjudan'),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading
                          ? _t('Saving…', 'Sparar…')
                          : _t('Send invite', 'Skicka inbjudan')),
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
        return SocialChoiceChip(
          label: o.label,
          selected: isSelected,
          onSelected: (_) => onChanged(o.value),
        );
      }).toList(),
    );
  }
}

class _GroupOption {
  final String id;
  final String name;

  const _GroupOption({
    required this.id,
    required this.name,
  });
}

class _InfoEditRow extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _InfoEditRow({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 18, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}

class _FixedTrackShape extends RoundedRectSliderTrackShape {
  final double horizontalPadding;

  const _FixedTrackShape({required this.horizontalPadding});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2.0;
    final double trackLeft = offset.dx + horizontalPadding;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth =
        parentBox.size.width - (horizontalPadding * 2);
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
