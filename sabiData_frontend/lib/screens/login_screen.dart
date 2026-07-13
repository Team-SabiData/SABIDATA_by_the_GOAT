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

/// Connexion par identifiants (email + mot de passe).
/// Intention backend : POST /auth/login {email, password} -> {token, user}.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _attempted = false;
  bool _loading = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? get _emailError =>
      _attempted && !_emailRe.hasMatch(_email.text.trim()) ? 'Email invalide.' : null;
  String? get _passwordError =>
      _attempted && _password.text.length < 6 ? 'Au moins 6 caractères.' : null;

  bool get _isValid =>
      _emailRe.hasMatch(_email.text.trim()) && _password.text.length >= 6;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _attempted = true);
    if (!_isValid) return;
    setState(() => _loading = true);
    try {
      await AuthApi().login(_email.text.trim(), _password.text);
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
              title: 'Bon retour',
              subtitle: 'Connectez-vous pour continuer à enrichir le patrimoine linguistique.',
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SpringTap(
                        onTap: () => showAppSnack(context, 'Réinitialisation — bientôt disponible.'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Text('Mot de passe oublié ?',
                            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Alternative : téléphone
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: Colors.black.withValues(alpha: 0.08))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('ou', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                        Expanded(child: Container(height: 1, color: Colors.black.withValues(alpha: 0.08))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: 'Continuer avec mon numéro',
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
                    label: 'Se connecter',
                    enabled: _isValid,
                    loading: _loading,
                    onTap: _login,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pas encore de compte ?',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      SpringTap(
                        onTap: () => context.go('/register'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Text('S\'inscrire',
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
