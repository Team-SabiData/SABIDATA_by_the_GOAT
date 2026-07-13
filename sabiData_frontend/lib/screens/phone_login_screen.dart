import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/primary_button.dart';
import '../data/api/auth_api.dart';
import '../data/api/api_exception.dart';

/// Connexion par numéro de téléphone + OTP (méthode alternative).
///
/// Cohérent avec le domaine : utilisateurs peu alphabétisés + retraits mobile
/// money ⇒ identité = MSISDN, vérifiée par code SMS.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _controller = TextEditingController();
  static const _dialCode = '+226';

  bool get _isValid => _controller.text.replaceAll(' ', '').length >= 8;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = '$_dialCode ${_controller.text.trim()}';
    try {
      await AuthApi().requestOtp(phone);
      if (!mounted) return;
      showAppSnack(context, 'Code envoyé par SMS au $phone');
      context.go('/verify', extra: phone);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
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
              title: 'Votre numéro',
              subtitle: 'Nous vous enverrons un code à 4 chiffres par SMS pour vous connecter sans mot de passe.',
              onBack: () => context.canPop() ? context.pop() : context.go('/login'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text('Numéro de téléphone',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.button)),
                          child: const Text(_dialCode,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                              borderRadius: BorderRadius.circular(AppRadius.button),
                            ),
                            child: TextField(
                              controller: _controller,
                              keyboardType: TextInputType.phone,
                              maxLength: 11,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 1.5),
                              cursorColor: AppColors.primary,
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                hintText: '70 00 00 00',
                                hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 1.5),
                                contentPadding: EdgeInsets.symmetric(vertical: 18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
              child: PrimaryButton(
                label: 'Recevoir le code →',
                enabled: _isValid,
                onTap: _sendCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
