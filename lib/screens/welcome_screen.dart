import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/social_chrome.dart';

class WelcomeScreen extends StatefulWidget {
  final AppState appState;

  const WelcomeScreen({super.key, required this.appState});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _authRedirect = 'social://auth-callback';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _isSignUp = false;

  bool get _isSv => widget.appState.locale.languageCode == 'sv';
  String _t(String en, String sv) => _isSv ? sv : en;

  void _normalizeEmailController(TextEditingController controller) {
    final text = controller.text;
    if (!text.contains('™')) return;
    final normalized = text.replaceAll('™', '@');
    final oldOffset = controller.selection.baseOffset;
    final newOffset =
        oldOffset > normalized.length ? normalized.length : oldOffset;
    controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showLanguageSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SocialSheetContent(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t('Choose language', 'Välj språk'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      widget.appState.setLocale(const Locale('en'));
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('English'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      widget.appState.setLocale(const Locale('sv'));
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Svenska'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _t('Enter email and password', 'Fyll i e-post och lösenord'))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _authRedirect,
        );
        if (!mounted) return;
        final requiresVerification = response.user?.emailConfirmedAt == null;
        if (requiresVerification) {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Account created. Check your email and verify before signing in.',
                'Konto skapat. Kontrollera e-post och verifiera innan du loggar in.',
              ),
            ),
          ),
        );
        setState(() {
          _isSignUp = false;
          _emailController.clear();
          _passwordController.clear();
        });
      } else {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        final confirmed = response.user?.emailConfirmedAt != null;
        if (!confirmed) {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  'Verify your email first. Check your inbox.',
                  'Verifiera din e-post först. Kontrollera inkorgen.',
                ),
              ),
            ),
          );
          return;
        }
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/invites', (route) => false);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final inputController =
        TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SocialDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: const Color(0xFF0F1A1A).withValues(alpha: 0.96),
          title: Text(_t('Reset password', 'Återställ lösenord')),
          content: TextField(
            controller: inputController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            autofillHints: const [AutofillHints.email],
            autofocus: true,
            onChanged: (_) => _normalizeEmailController(inputController),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: _t('Email', 'E-post'),
              hintText: 'name@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('Cancel', 'Avbryt')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, inputController.text.trim()),
              child: Text(_t('Send', 'Skicka')),
            ),
          ],
        );
      },
    );
    inputController.dispose();

    if (email == null || email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _authRedirect,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Password reset email sent.',
              'Återställningsmail skickat.',
            ),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t("Error", "Fel")}: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2DD4CF);
    final textMuted = Colors.white.withValues(alpha: 0.62);
    final inputFill = Colors.white.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: const Color(0xFF030608),
      body: Stack(
        children: [
          const SocialBackground(
            showOrbs: false,
            child: SizedBox.expand(),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            right: -100,
            bottom: 150,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0891B2).withValues(alpha: 0.14),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'S',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _loading ? null : _showLanguageSheet,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.22)),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isSv ? 'Svenska' : 'English'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Social',
                    style: GoogleFonts.oleoScript(
                      fontSize: 68,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF22D3EE),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _t('Connect. Share. Belong.', 'Connect. Share. Belong.'),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _t('Email', 'E-post'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          enableSuggestions: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) =>
                              _normalizeEmailController(_emailController),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: Colors.white60),
                            hintText: 'name@example.com',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: inputFill,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _t('Password', 'Lösenord'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          enabled: !_loading,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: Colors.white60),
                            suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white60,
                              ),
                            ),
                            hintText: '********',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: inputFill,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: accent),
                            ),
                          ),
                        ),
                        if (!_isSignUp) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: Text(
                                _t('Forgot password?', 'Glömt lösenord?'),
                                style: const TextStyle(
                                    color: accent, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _loading ? null : _submitAuth,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    _isSignUp
                                        ? _t('Sign up', 'Registrera')
                                        : _t('Sign in', 'Logga in'),
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp
                                  ? _t('Already have an account?',
                                      'Har du redan konto?')
                                  : _t('Don\'t have an account?',
                                      'Har du inget konto?'),
                              style: TextStyle(color: textMuted, fontSize: 15),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () =>
                                      setState(() => _isSignUp = !_isSignUp),
                              child: Text(
                                _isSignUp
                                    ? _t('Sign in', 'Logga in')
                                    : _t('Sign up', 'Registrera'),
                                style: const TextStyle(
                                    color: accent, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    '© 2026 Social. ${_t('All rights reserved.', 'Alla rättigheter förbehållna.')}',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
