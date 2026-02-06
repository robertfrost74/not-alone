import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';
import 'groups_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  final AppState appState;

  const CreateGroupScreen({super.key, required this.appState});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _saving = false;

  bool get isSv => widget.appState.isSv;
  String _t(String en, String sv) => widget.appState.t(en, sv);

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Group name is required', 'Gruppnamn krävs'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('You must be logged in', 'Du måste vara inloggad'))),
        );
        return;
      }

      final created = await supabase
          .from('groups')
          .insert({
            'name': name,
            'description': _descController.text.trim(),
            'owner_id': user.id,
          })
          .select()
          .single();

      final groupId = created['id'] as String;

      await supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': user.id,
        'role': 'owner',
        'display_name': _displayNameFor(user),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupsScreen(appState: widget.appState),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not create group: $error',
              'Kunde inte skapa grupp: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _displayNameFor(User user) {
    final metadata = user.userMetadata ?? const {};
    final username = (metadata['username'] ?? '').toString().trim();
    final fullName = (metadata['full_name'] ?? '').toString().trim();
    final email = (user.email ?? '').trim();
    if (username.isNotEmpty) return username;
    if (fullName.isNotEmpty) return fullName;
    return email.isNotEmpty ? email : user.id;
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
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

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('Create group', 'Skapa grupp')),
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
                  _label(_t('Group name', 'Gruppnamn')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration(hint: _t('e.g. Weekend Walkers', 't.ex. Helgpromenader')),
                  ),
                  const SizedBox(height: 14),
                  _label(_t('Description', 'Beskrivning')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    minLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                        hint: _t('What is this group about?', 'Vad handlar gruppen om?')),
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _createGroup,
                      child: Text(_saving
                          ? _t('Creating...', 'Skapar...')
                          : _t('Create group', 'Skapa grupp')),
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
