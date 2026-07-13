import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../widgets/auth_field.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/spring_tap.dart';
import '../data/api/auth_api.dart';
import '../data/api/api_exception.dart';

/// Inscription (création de compte).
/// Intention backend : POST /auth/register {name, email, phone, password}
/// -> {token, user} (puis vérification du numéro via /verify).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _attempted = false;
  bool _loading = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? get _nameError =>
      _attempted && _name.text.trim().length < 2 ? 'Entrez votre nom.' : null;
  String? get _emailError =>
      _attempted && !_emailRe.hasMatch(_email.text.trim()) ? 'Email invalide.' : null;
  String? get _passwordError =>
      _attempted && _password.text.length < 6 ? 'Au moins 6 caractères.' : null;
  String? get _confirmError =>
      _attempted && _confirm.text != _password.text ? 'Les mots de passe diffèrent.' : null;

  bool get _isValid =>
      _name.text.trim().length >= 2 &&
      _emailRe.hasMatch(_email.text.trim()) &&
      _password.text.length >= 6 &&
      _confirm.text == _password.text;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _password, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _attempted = true);
    if (!_isValid) return;
    setState(() => _loading = true);
    try {
      await AuthApi().register(_name.text.trim(), _email.text.trim(), _password.text);
      if (mounted) context.go(AuthApi.nextRoute());
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingHeader(
              title: 'Créer un compte',
              subtitle: 'Rejoignez la communauté qui préserve les langues nationales.',
              onBack: () => context.canPop() ? context.pop() : context.go('/login'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    AuthField(
                      label: 'Nom complet',
                      hint: 'Adama Ouédraogo',
                      controller: _name,
                      keyboardType: TextInputType.name,
                      errorText: _nameError,
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Email',
                      hint: 'vous@exemple.bf',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Mot de passe',
                      hint: '••••••••',
                      controller: _password,
                      obscure: true,
                      errorText: _passwordError,
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Confirmer le mot de passe',
                      hint: '••••••••',
                      controller: _confirm,
                      obscure: true,
                      errorText: _confirmError,
                    ),
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: 'S\'inscrire avec un numéro',
                      icon: Icons.phone_iphone_rounded,
                      onTap: () => context.go('/phone-login'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Créer mon compte',
                    enabled: _isValid,
                    loading: _loading,
                    onTap: _register,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Déjà un compte ?',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      SpringTap(
                        onTap: () => context.go('/login'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Text('Se connecter',
                            style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
