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

/// Vérification du code SMS (étape 2/2). [phone] est affiché pour rassurer
/// l'utilisateur ; il provient de l'écran de connexion via `extra`.
class OtpScreen extends StatefulWidget {
  final String? phone;

  const OtpScreen({super.key, this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _length = 4;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get _code => _controller.text;
  bool get _isComplete => _code.length == _length;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
      if (_code.length == _length && !_loading) _verify();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();
    try {
      await AuthApi().verifyOtp(widget.phone ?? '', _code);
      if (mounted) context.go(AuthApi.nextRoute());
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message);
        _controller.clear();
      }
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
              title: 'Vérification',
              subtitle: widget.phone != null
                  ? 'Entrez le code à 4 chiffres envoyé au ${widget.phone}.'
                  : 'Entrez le code à 4 chiffres reçu par SMS.',
              onBack: () => context.canPop() ? context.pop() : context.go('/login'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Champ caché qui capture la saisie ; les cases ne font que l'afficher.
                    GestureDetector(
                      onTap: () => _focus.requestFocus(),
                      child: Stack(
                        children: [
                          // Champ réel invisible : clavier numérique, collage supporté.
                          Opacity(
                            opacity: 0,
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              keyboardType: TextInputType.number,
                              maxLength: _length,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(_length, (i) {
                              final filled = i < _code.length;
                              final active = i == _code.length;
                              return Container(
                                width: 56,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(
                                    color: active
                                        ? AppColors.primary
                                        : filled
                                            ? AppColors.textPrimary
                                            : AppColors.border,
                                    width: active ? 2 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                ),
                                child: Text(
                                  filled ? _code[i] : '',
                                  style: AppText.numeric(22),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () => showAppSnack(context, 'Nouveau code envoyé par SMS.'),
                        child: const Text('Renvoyer le code',
                          style: TextStyle(fontSize: 15, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
              child: PrimaryButton(
                label: 'Vérifier →',
                enabled: _isComplete && !_loading,
                loading: _loading,
                onTap: _verify,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
