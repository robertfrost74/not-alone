import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';

class EditInviteScreen extends StatefulWidget {
  final AppState appState;
  final Map<String, dynamic> invite;

  const EditInviteScreen({
    super.key,
    required this.appState,
    required this.invite,
  });

  @override
  State<EditInviteScreen> createState() => _EditInviteScreenState();
}

class _EditInviteScreenState extends State<EditInviteScreen> {
  late String _activity;
  late int _duration;
  late int _maxParticipants;
  late String _mode;
  late TextEditingController _placeController;
  late DateTime _meetingTime;
  late RangeValues _ageRange;
  late String _targetGender;
  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _saving = false;

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  @override
  void initState() {
    super.initState();
    final invite = widget.invite;
    _activity = _normalizeActivity((invite['activity'] ?? 'walk').toString());
    _duration = (invite['duration'] as num?)?.toInt() ??
        int.tryParse(invite['duration']?.toString() ?? '') ??
        20;
    _maxParticipants = (invite['max_participants'] as num?)?.toInt() ??
        int.tryParse(invite['max_participants']?.toString() ?? '') ??
        2;
    _mode = _normalizeMode((invite['mode'] ?? '').toString());
    _placeController =
        TextEditingController(text: (invite['place'] ?? '').toString());
    _meetingTime =
        _parseDateTime(invite['meeting_time']) ?? DateTime.now().add(const Duration(minutes: 10));
    _ageRange = RangeValues(
      ((invite['age_min'] as num?)?.toDouble() ??
              double.tryParse(invite['age_min']?.toString() ?? '') ??
              16)
          .clamp(16, 120),
      ((invite['age_max'] as num?)?.toDouble() ??
              double.tryParse(invite['age_max']?.toString() ?? '') ??
              120)
          .clamp(16, 120),
    );
    if (_ageRange.start > _ageRange.end) {
      _ageRange = RangeValues(_ageRange.end, _ageRange.start);
    }
    _targetGender =
        _normalizeGender((invite['target_gender'] ?? 'all').toString());
    if (_targetGender != 'male' && _targetGender != 'female') {
      _targetGender = 'all';
    }
    _selectedGroupId = invite['group_id']?.toString();
    final groupRow = invite['groups'] as Map<String, dynamic>?;
    _selectedGroupName = (groupRow?['name'] ?? '').toString();
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  String _normalizeActivity(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'fika' ||
        normalized == 'coffee' ||
        normalized == 'kaffe') {
      return 'coffee';
    }
    if (normalized == 'promenad' || normalized == 'walk') return 'walk';
    if (normalized == 'träna' ||
        normalized == 'trana' ||
        normalized == 'workout') {
      return 'workout';
    }
    if (normalized == 'lunch' || normalized == 'luncha') return 'lunch';
    if (normalized == 'middag' || normalized == 'dinner') return 'dinner';
    return normalized;
  }

  String _normalizeMode(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1to1' ||
        normalized == '1:1' ||
        normalized == 'one-to-one' ||
        normalized == 'one to one') {
      return 'one_to_one';
    }
    return normalized;
  }

  String _normalizeGender(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'man' || v == 'män' || v == 'male') return 'male';
    if (v == 'kvinna' || v == 'kvinnor' || v == 'female') return 'female';
    if (v == 'alla' || v == 'all') return 'all';
    return v;
  }

  String _activityLabel(String a) {
    switch (a) {
      case 'walk':
        return isSv ? 'Promenad' : 'Walk';
      case 'coffee':
        return 'Fika';
      case 'workout':
        return isSv ? 'Träna' : 'Workout';
      case 'lunch':
        return isSv ? 'Luncha' : 'Lunch';
      case 'dinner':
        return isSv ? 'Middag' : 'Dinner';
      default:
        return a;
    }
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return _t('Not set', 'Inte satt');
    final parsed = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    final y = parsed.year.toString().padLeft(4, '0');
    final mo = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    final h = parsed.hour.toString().padLeft(2, '0');
    final mi = parsed.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  Future<void> _pickMeetingTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _meetingTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isSv ? 'Välj datum' : 'Pick date',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_meetingTime),
      helpText: isSv ? 'Välj tid' : 'Pick time',
    );
    if (time == null || !mounted) return;
    setState(() {
      _meetingTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickGroup() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final rows = await Supabase.instance.client
        .from('group_members')
        .select('group_id, groups ( id, name )')
        .match({'user_id': userId});
    final List<_GroupOption> options = [];
    final seen = <String>{};
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final group = row['groups'] as Map<String, dynamic>?;
      if (group == null) continue;
      final id = group['id']?.toString() ?? '';
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      options.add(_GroupOption(
        id: id,
        name: (group['name'] ?? '').toString(),
      ));
    }

    if (!mounted) return;
    String? tempSelected = _selectedGroupId;
    String? tempName = _selectedGroupName;
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return SocialDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          title: Text(_t('Choose group', 'Välj grupp')),
          content: options.isEmpty
              ? Text(_t('No groups yet', 'Inga grupper ännu'))
              : Theme(
                  data: Theme.of(dialogContext).copyWith(
                    unselectedWidgetColor: Colors.white60,
                    radioTheme: RadioThemeData(
                      fillColor:
                          WidgetStateProperty.resolveWith<Color>(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xFF2DD4CF)
                            : Colors.white60,
                      ),
                    ),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setInnerState) {
                      return RadioGroup<String?>(
                        groupValue: tempSelected,
                        onChanged: (v) {
                          setInnerState(() {
                            tempSelected = v;
                            if (v == null) {
                              tempName = null;
                            } else {
                              final selected = options.firstWhere(
                                (g) => g.id == v,
                                orElse: () =>
                                    const _GroupOption(id: '', name: ''),
                              );
                              tempName =
                                  selected.name.isEmpty ? null : selected.name;
                            }
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<String?>(
                              value: null,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _t('All users', 'Alla'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...options.map(
                              (g) => RadioListTile<String?>(
                                value: g.id,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  g.name.isEmpty
                                      ? _t('Unnamed group', 'Grupp utan namn')
                                      : g.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(_t('Cancel', 'Avbryt')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, tempSelected),
              child: Text(_t('Save', 'Spara')),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _selectedGroupId = result;
      _selectedGroupName = tempName;
      if (_selectedGroupId != null) {
        _targetGender = 'all';
      }
    });
  }

  Future<void> _save() async {
    final inviteId = widget.invite['id']?.toString();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (inviteId == null || userId == null) return;

    final updatedPlace = _placeController.text.trim();
    if (updatedPlace.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Enter place', 'Ange plats'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('invites').update({
        'activity': _activity,
        'place': updatedPlace,
        'duration': _duration,
        'meeting_time': _meetingTime.toIso8601String(),
        'max_participants': _mode == 'one_to_one' ? null : _maxParticipants,
        'age_min': _ageRange.start.round(),
        'age_max': _ageRange.end.round(),
        'target_gender': _targetGender,
        'group_id': _selectedGroupId,
      }).match({
        'id': inviteId,
        'host_user_id': userId,
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
    final activityItems = [
      DropdownMenuItem(
          value: 'walk', child: Text(isSv ? 'Promenad' : 'Walk')),
      const DropdownMenuItem(value: 'coffee', child: Text('Fika')),
      DropdownMenuItem(
          value: 'workout', child: Text(isSv ? 'Träna' : 'Workout')),
      DropdownMenuItem(
          value: 'lunch', child: Text(isSv ? 'Luncha' : 'Lunch')),
      DropdownMenuItem(
          value: 'dinner', child: Text(isSv ? 'Middag' : 'Dinner')),
    ];
    final activityValues =
        activityItems.map((e) => e.value).whereType<String>();
    if (!activityValues.contains(_activity)) {
      activityItems.add(
        DropdownMenuItem(
          value: _activity,
          child: Text(_activityLabel(_activity)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Edit invite', 'Redigera inbjudan')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SocialBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Activity', 'Aktivitet'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _activity,
                      dropdownColor: const Color(0xFF10201E),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: activityItems,
                      onChanged: (v) => setState(() => _activity = v ?? _activity),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('Meeting place', 'Mötesplats'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _placeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _t('Enter place', 'Ange plats'),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_t('Time', 'Tid')}: ${_formatDateTime(_meetingTime)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _pickMeetingTime,
                        child: Text(_t('Change time', 'Ändra tid')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_t('Duration', 'Längd')}: $_duration min',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      min: 10,
                      max: 180,
                      divisions: 170,
                      value: _duration.toDouble().clamp(10, 180),
                      label: '$_duration',
                      onChanged: (v) => setState(() => _duration = v.round()),
                    ),
                    if (_mode != 'one_to_one') ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_t('Max participants', 'Max antal')}: $_maxParticipants',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        min: 1,
                        max: 20,
                        divisions: 19,
                        value: _maxParticipants.toDouble().clamp(1, 20),
                        label: '$_maxParticipants',
                        onChanged: (v) =>
                            setState(() => _maxParticipants = v.round()),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${_t('Age range', 'Ålders spann')}: ${_ageRange.start.round()}-${_ageRange.end.round()}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    RangeSlider(
                      min: 16,
                      max: 120,
                      divisions: 104,
                      values: _ageRange,
                      labels: RangeLabels(
                        '${_ageRange.start.round()}',
                        '${_ageRange.end.round()}',
                      ),
                      onChanged: (v) => setState(() => _ageRange = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('Show invite for', 'Visa inbjudan för'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SocialChoiceChip(
                          label: _t('All', 'Alla'),
                          selected: _selectedGroupId == null &&
                              _targetGender == 'all',
                          onSelected: (_) => setState(() {
                            _selectedGroupId = null;
                            _selectedGroupName = null;
                            _targetGender = 'all';
                          }),
                        ),
                        SocialChoiceChip(
                          label: _t('Men', 'Män'),
                          selected: _selectedGroupId == null &&
                              _targetGender == 'male',
                          onSelected: (_) => setState(() {
                            _selectedGroupId = null;
                            _selectedGroupName = null;
                            _targetGender = 'male';
                          }),
                        ),
                        SocialChoiceChip(
                          label: _t('Women', 'Kvinnor'),
                          selected: _selectedGroupId == null &&
                              _targetGender == 'female',
                          onSelected: (_) => setState(() {
                            _selectedGroupId = null;
                            _selectedGroupName = null;
                            _targetGender = 'female';
                          }),
                        ),
                        SocialChoiceChip(
                          label: _t('Group', 'Grupp'),
                          selected: _selectedGroupId != null,
                          onSelected: (_) => _pickGroup(),
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
                            _t('Group', 'Grupp'),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving
                              ? _t('Saving…', 'Sparar…')
                              : _t('Save changes', 'Spara ändringar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupOption {
  final String id;
  final String name;

  const _GroupOption({required this.id, required this.name});
}
