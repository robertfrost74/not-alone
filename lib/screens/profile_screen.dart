import 'package:flutter/material.dart';
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
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _interestsController = TextEditingController();
  String _avatarUrl = '';
  bool _saving = false;

  bool get isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => isSv ? sv : en;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const {};
    _usernameController.text = (metadata['username'] ?? '').toString();
    _fullNameController.text = (metadata['full_name'] ?? '').toString();
    _bioController.text = (metadata['bio'] ?? '').toString();
    _cityController.text = (metadata['city'] ?? '').toString();
    _interestsController.text = (metadata['interests'] ?? '').toString();
    _avatarUrl = (metadata['avatar_url'] ?? '').toString();
  }

  Future<void> _editAvatarUrl() async {
    final controller = TextEditingController(text: _avatarUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.white24),
          ),
          title: Text(_t('Upload image', 'Ladda upp bild')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: _t('Image URL', 'Bild-URL'),
              hintText: 'https://...',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('Cancel', 'Avbryt')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(_t('Save', 'Spara')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => _avatarUrl = value.trim());
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Username is required', 'Användarnamn krävs'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'full_name': _fullNameController.text.trim(),
            'bio': _bioController.text.trim(),
            'city': _cityController.text.trim(),
            'interests': _interestsController.text.trim(),
            'avatar_url': _avatarUrl,
          },
        ),
      );
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
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.white12,
                          backgroundImage:
                              _avatarUrl.isEmpty ? null : NetworkImage(_avatarUrl),
                          child: _avatarUrl.isEmpty
                              ? const Icon(Icons.person, size: 44, color: Colors.white70)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: FilledButton(
                            onPressed: _editAvatarUrl,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(42, 42),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.edit, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel(_t('Username', 'Användarnamn')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Real name', 'Riktigt namn')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fullNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Bio', 'Om mig')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    minLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('City', 'Stad')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(_t('Interests', 'Intressen')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _interestsController,
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
