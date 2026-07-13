import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';

/// Saisie du montant + confirmation de retrait. [provider] vient de l'écran
/// Revenus via `extra`. Intention backend : POST /withdrawals {amount,provider}.
class WithdrawScreen extends StatefulWidget {
  final String? provider;

  const WithdrawScreen({super.key, this.provider});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  static const _balance = 2750; // FCFA — mock (= GET /me/wallet)
  static const _min = 500;

  final _controller = TextEditingController();
  bool _submitted = false;

  String get _provider => widget.provider ?? 'Orange Money';
  int get _amount => int.tryParse(_controller.text.trim()) ?? 0;

  String? get _error {
    if (_controller.text.isEmpty) return null;
    if (_amount < _min) return 'Minimum $_min FCFA.';
    if (_amount > _balance) return 'Solde insuffisant (max $_balance FCFA).';
    return null;
  }

  bool get _isValid => _amount >= _min && _amount <= _balance;

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

  void _setAmount(int v) {
    _controller.text = v.toString();
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
  }

  void _confirm() {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: AppBody(
          child: AppEmptyState(
            icon: Icons.check_circle_rounded,
            title: 'Retrait demandé',
            message: '$_amount FCFA seront envoyés sur votre compte $_provider sous 24h.',
            actionLabel: 'Terminé',
            onAction: () => context.go('/revenue'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MotifHeader(
              motif: 'assets/motifs/motif_grandir.png',
              title: 'Retrait',
              height: 128,
              scrim: const Color(0xFF241608),
              onBack: () => context.canPop() ? context.pop() : context.go('/revenue'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Available balance
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Solde disponible',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                          const SizedBox(height: 6),
                          const Text('$_balance FCFA',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Montant à retirer',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(
                          color: _error != null ? AppColors.red : AppColors.primary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              cursorColor: AppColors.primary,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(color: AppColors.textMuted),
                                contentPadding: EdgeInsets.symmetric(vertical: 18),
                              ),
                            ),
                          ),
                          const Text('FCFA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 12),
                    // Quick amounts
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickChip(label: '500', onTap: () => _setAmount(500)),
                        _QuickChip(label: '1 000', onTap: () => _setAmount(1000)),
                        _QuickChip(label: '2 000', onTap: () => _setAmount(2000)),
                        _QuickChip(label: 'Tout ($_balance)', onTap: () => _setAmount(_balance)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Vers',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.smartphone_rounded, size: 20, color: AppColors.textPrimary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(_provider,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                          const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Paiement traité sous 24h · sans frais.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: PrimaryButton(
                label: 'Confirmer le retrait',
                color: AppColors.green,
                enabled: _isValid,
                onTap: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ),
    );
  }
}
