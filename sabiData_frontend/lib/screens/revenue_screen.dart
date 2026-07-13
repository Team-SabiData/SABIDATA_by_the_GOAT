import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_card.dart';
import '../data/api/wallet_api.dart';
import '../data/api/ledger_api.dart';
import '../data/gamification/level.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  String _selectedProvider = 'Orange Money';
  Map<String, dynamic>? _wallet;

  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadHistory();
  }

  Future<void> _loadWallet() async {
    try {
      final w = await WalletApi().getWallet();
      if (mounted) setState(() => _wallet = w);
    } catch (_) {
      // garde l'écran utilisable même hors-ligne ; le solde reste « — ».
    }
  }

  Future<void> _loadHistory() async {
    try {
      final h = await LedgerApi().history();
      if (mounted) setState(() => _history = h);
    } catch (_) {
      // garde l'écran utilisable même hors-ligne ; l'historique reste vide.
    }
  }

  static const _reasonMeta = {
    'record': {'icon': Icons.mic_rounded, 'bg': 0xFF2BC49A, 'title': 'Enregistrement'},
    'validate': {'icon': Icons.hearing_rounded, 'bg': 0xFF4A9EF5, 'title': 'Validation'},
    'transcribe': {'icon': Icons.edit_rounded, 'bg': 0xFFE87D3E, 'title': 'Transcription'},
    'convert': {'icon': Icons.sync_rounded, 'bg': 0xFF7B2D8B, 'title': 'Conversion'},
    'withdrawal': {'icon': Icons.arrow_outward_rounded, 'bg': 0xFFE11D28, 'title': 'Retrait'},
    'withdrawal_refund': {'icon': Icons.undo_rounded, 'bg': 0xFF2BC49A, 'title': 'Remboursement retrait'},
    'admin_adjustment': {'icon': Icons.tune_rounded, 'bg': 0xFF9BA3B5, 'title': 'Ajustement'},
  };

  Map<String, dynamic> _entryDisplay(Map<String, dynamic> h) {
    final reason = h['reason'] as String?;
    final meta = _reasonMeta[reason] ?? {'icon': Icons.savings_rounded, 'bg': 0xFF9BA3B5, 'title': reason ?? 'Gain'};
    final delta = (h['delta'] as num?)?.toInt() ?? 0;
    String date = '';
    final createdAt = h['createdAt'] as String?;
    if (createdAt != null) {
      try {
        final d = DateTime.parse(createdAt).toLocal();
        date = '${d.day}/${d.month} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    var amount = '${delta >= 0 ? '+' : ''}$delta pts';
    if (h['state'] == 'provisional') amount += ' (en attente)';
    return {
      'icon': meta['icon'],
      'bg': meta['bg'],
      'title': meta['title'],
      'date': date,
      'amount': amount,
    };
  }

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  /// Mois courant, ex. « Juillet 2026 ».
  String get _monthLabel {
    final now = DateTime.now();
    return '${_months[now.month - 1]} ${now.year}';
  }

  String get _balanceText => _wallet == null ? '—' : '${_wallet!['balanceFcfa']} ';
  int get _pointsTotal => (_wallet?['pointsTotal'] as int?) ?? 0;
  int get _pointsPending => (_wallet?['pointsPending'] as int?) ?? 0;

  static const _providers = [
    {'name': 'Orange Money', 'icon': Icons.smartphone_rounded},
    {'name': 'Moov Money', 'icon': Icons.smartphone_rounded},
    {'name': 'Wave', 'icon': Icons.waves_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final locked = (_wallet?['level'] as String?) == 'bronze';
    final count = (_wallet?['contributionsValidated'] as int?) ?? 0;
    final remaining = (LevelInfo.argentAt - count).clamp(0, LevelInfo.argentAt);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            MotifHeader(
              motif: 'assets/motifs/motif_grandir.png',
              title: 'Mes Revenus',
              subtitle: _monthLabel,
              height: 150,
              scrim: const Color(0xFF241608),
              onBack: () => context.go('/dashboard'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFFF6F2), const Color(0xFFFFEFE9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Solde disponible',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green, letterSpacing: 0.08 * 12)),
                          const SizedBox(height: 10),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: _balanceText,
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.04 * 40)),
                                const TextSpan(text: 'FCFA',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('$_pointsTotal pts confirmés · $_pointsPending en attente',
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Withdrawal providers
                    Text('Retrait via', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04 * 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: _providers.map((p) {
                        final name = p['name'] as String;
                        final isSelected = _selectedProvider == name;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedProvider = name),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.08),
                                  width: isSelected ? 2 : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Icon(p['icon'] as IconData, size: 24, color: AppColors.textPrimary),
                                  const SizedBox(height: 6),
                                  Text(name, textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    if (locked) ...[
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Retrait débloqué au niveau Argent — encore $remaining contributions validées.',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // Withdraw button
                    PrimaryButton(
                      label: 'Retirer → $_selectedProvider',
                      color: AppColors.green,
                      enabled: !locked,
                      onTap: () => context.go('/withdraw', extra: _selectedProvider),
                    ),
                    const SizedBox(height: 8),
                    const Text('Minimum 500 FCFA · Paiement dans 24h',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    // History
                    Text('Historique des gains',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04 * 12)),
                    const SizedBox(height: 10),
                    if (_history.isEmpty)
                      const Text('Aucun gain pour l\'instant.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                    else
                      ..._history.map((raw) {
                        final h = _entryDisplay(raw);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: Color(h['bg'] as int).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(h['icon'] as IconData, size: 16, color: Color(h['bg'] as int)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      Text(h['date'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text(h['amount'] as String,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
