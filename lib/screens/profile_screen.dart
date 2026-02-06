import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';

class ProfileScreen extends StatefulWidget {
  final AppState appState;

  const ProfileScreen({super.key, required this.appState});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _interestsController = TextEditingController();
  String _gender = 'male'; // male | female
  String _avatarUrl = '';
  String _avatarPresetId = '';
  bool _saving = false;

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  String _fixMojibake(String value) {
    return value
        .replaceAll('Ã¥', 'å')
        .replaceAll('Ã¤', 'ä')
        .replaceAll('Ã¶', 'ö')
        .replaceAll('Ã…', 'Å')
        .replaceAll('Ã„', 'Ä')
        .replaceAll('Ã–', 'Ö');
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const {};
    _usernameController.text = _fixMojibake((metadata['username'] ?? '').toString());
    _fullNameController.text = _fixMojibake((metadata['full_name'] ?? '').toString());
    _ageController.text = (metadata['age'] ?? '').toString();
    _bioController.text = _fixMojibake((metadata['bio'] ?? '').toString());
    _cityController.text = _fixMojibake((metadata['city'] ?? '').toString());
    _interestsController.text = _fixMojibake((metadata['interests'] ?? '').toString());
    _avatarUrl = _fixMojibake((metadata['avatar_url'] ?? '').toString());
    _avatarPresetId = (metadata['avatar_preset_id'] ?? '').toString();
    final rawGender = (metadata['gender'] ?? '').toString().toLowerCase().trim();
    _gender = rawGender == 'female' ? 'female' : 'male';
  }

  Future<void> _showAvatarPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1A1A),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SocialSheetContent(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Choose avatar', 'Välj avatar'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _presetAvatars.length + 1,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index == _presetAvatars.length) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _pickAndUploadAvatar();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2DD4CF)),
                              color: Colors.white10,
                            ),
                            child: const Icon(
                              Icons.add_a_photo_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        );
                      }

                      final preset = _presetAvatars[index];
                      final selected = _avatarPresetId == preset.id && _avatarUrl.isEmpty;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() {
                            _avatarPresetId = preset.id;
                            _avatarUrl = '';
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white10,
                            border: Border.all(
                              color: selected ? const Color(0xFF2DD4CF) : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              preset.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'Upload is temporarily disabled while we fix iOS build settings.',
            'Uppladdning är tillfälligt avstängd medan vi fixar iOS build-inställningar.',
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    final ageRaw = _ageController.text.trim();
    final age = ageRaw.isEmpty ? null : int.tryParse(ageRaw);
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Username is required', 'Användarnamn krävs'))),
      );
      return;
    }
    if (ageRaw.isNotEmpty && age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Age must be a number', 'Ålder måste vara ett nummer'))),
      );
      return;
    }
    if (age != null && (age < 13 || age > 120)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Age must be between 13 and 120', 'Ålder måste vara mellan 13 och 120'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'full_name': _fixMojibake(_fullNameController.text.trim()),
            'age': age,
            'gender': _gender,
            'bio': _fixMojibake(_bioController.text.trim()),
            'city': _fixMojibake(_cityController.text.trim()),
            'interests': _fixMojibake(_interestsController.text.trim()),
            'avatar_url': _avatarUrl,
            'avatar_preset_id': _avatarPresetId,
          },
        ),
      );
      await supabase.from('profiles').upsert({
        'id': supabase.auth.currentUser?.id,
        'username': username,
        'full_name': _fixMojibake(_fullNameController.text.trim()),
        'age': age,
        'gender': _gender,
        'bio': _fixMojibake(_bioController.text.trim()),
        'city': _fixMojibake(_cityController.text.trim()),
        'interests': _fixMojibake(_interestsController.text.trim()),
        'avatar_url': _fixMojibake(_avatarUrl),
        'avatar_preset_id': _avatarPresetId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await supabase.from('group_members').update({
          'display_name': username,
        }).match({'user_id': currentUser.id});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Profile saved', 'Profil sparad'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('Error', 'Fel')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2DD4CF)),
      ),
    );
  }

  List<TextInputFormatter> get _svTextFormatters {
    if (!isSv) return const [];
    return const [_SwedishKeyMapFormatter()];
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Profile', 'Profil')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SocialBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SocialPanel(
              child: ListView(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        _AvatarPreview(
                          avatarUrl: _avatarUrl,
                          avatarPresetId: _avatarPresetId,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: FilledButton(
                            onPressed: _showAvatarPicker,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(42, 42),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child:
                                const Icon(Icons.photo_camera_outlined, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _t(
                        'Choose avatar (upload is temporarily disabled)',
                        'Välj avatar (uppladdning är tillfälligt avstängd)',
                      ),
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel(_t('Username', 'Användarnamn')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    inputFormatters: _svTextFormatters,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Real name', 'Riktigt namn')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fullNameController,
                    inputFormatters: _svTextFormatters,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Age', 'Ålder')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(hintText: _t('e.g. 28', 't.ex. 28')),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Gender', 'Kön')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SocialChoiceChip(
                        label: _t('Man', 'Man'),
                        selected: _gender == 'male',
                        onSelected: (_) => setState(() => _gender = 'male'),
                      ),
                      SocialChoiceChip(
                        label: _t('Woman', 'Kvinna'),
                        selected: _gender == 'female',
                        onSelected: (_) => setState(() => _gender = 'female'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Bio', 'Om mig')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    minLines: 3,
                    inputFormatters: _svTextFormatters,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('City', 'Stad')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cityController,
                    inputFormatters: _svTextFormatters,
                    keyboardType: TextInputType.streetAddress,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Interests', 'Intressen')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _interestsController,
                    inputFormatters: _svTextFormatters,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      hintText:
                          _t('Walk, workout, fika...', 'Promenad, träna, fika...'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Email', 'E-post')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                      color: Colors.white10,
                    ),
                    child: Text(
                      email.isEmpty ? '-' : email,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: Text(_saving ? _t('Saving...', 'Sparar...') : _t('Save profile', 'Spara profil')),
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

class _SwedishKeyMapFormatter extends TextInputFormatter {
  const _SwedishKeyMapFormatter();

  static const Map<String, String> _charMap = {
    '[': 'å',
    '\'': 'ä',
    ';': 'ö',
    '{': 'Å',
    '"': 'Ä',
    ':': 'Ö',
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    for (final entry in _charMap.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    if (text == newValue.text) return newValue;
    return newValue.copyWith(text: text, composing: TextRange.empty);
  }
}

class _AvatarPreset {
  final String id;
  final String assetPath;

  const _AvatarPreset({
    required this.id,
    required this.assetPath,
  });
}

const List<_AvatarPreset> _presetAvatars = [
  _AvatarPreset(id: 'a1', assetPath: 'assets/avatars/a1.png'),
  _AvatarPreset(id: 'a2', assetPath: 'assets/avatars/a2.png'),
  _AvatarPreset(id: 'a3', assetPath: 'assets/avatars/a3.png'),
  _AvatarPreset(id: 'a4', assetPath: 'assets/avatars/a4.png'),
  _AvatarPreset(id: 'a5', assetPath: 'assets/avatars/a5.png'),
  _AvatarPreset(id: 'a6', assetPath: 'assets/avatars/a6.png'),
  _AvatarPreset(id: 'a7', assetPath: 'assets/avatars/a7.png'),
  _AvatarPreset(id: 'a8', assetPath: 'assets/avatars/a8.png'),
  _AvatarPreset(id: 'a9', assetPath: 'assets/avatars/a9.png'),
  _AvatarPreset(id: 'a10', assetPath: 'assets/avatars/a10.png'),
  _AvatarPreset(id: 'a11', assetPath: 'assets/avatars/a11.png'),
  _AvatarPreset(id: 'a12', assetPath: 'assets/avatars/a12.png'),
];

class _AvatarPreview extends StatelessWidget {
  final String avatarUrl;
  final String avatarPresetId;

  const _AvatarPreview({
    required this.avatarUrl,
    required this.avatarPresetId,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundColor: Colors.white12,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    _AvatarPreset? preset;
    for (final item in _presetAvatars) {
      if (item.id == avatarPresetId) {
        preset = item;
        break;
      }
    }
    if (preset != null) {
      return CircleAvatar(
        radius: 52,
        backgroundColor: Colors.white12,
        backgroundImage: AssetImage(preset.assetPath),
      );
    }

    return const CircleAvatar(
      radius: 52,
      backgroundColor: Colors.white12,
      child: Icon(Icons.person, size: 44, color: Colors.white70),
    );
  }
}
