import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../data/auth/auth_session.dart';
import '../data/api/auth_api.dart';
import '../data/api/wallet_api.dart';
import '../data/gamification/level.dart';

/// Profil & réglages. Point d'entrée depuis l'en-tête du dashboard.
/// Complète la boucle d'auth (déconnexion) et regroupe les réglages
/// jusque-là sans écran (langues, dialecte, notifications).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;
  Map<String, dynamic>? _wallet;

  @override
  void initState() {
    super.initState();
    AuthApi().refreshMe().catchError((_) {}); // meilleur-effort : garde les valeurs connues
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final w = await WalletApi().getWallet();
      if (mounted) setState(() => _wallet = w);
    } catch (_) {
      // garde l'écran utilisable même hors-ligne ; le solde reste « — ».
    }
  }

  String get _balanceText => _wallet == null ? '—' : '${_wallet!['balanceFcfa']}';

  void _logout() {
    AuthSession.instance.clear(); // vide token + refresh + profil (mémoire + persistance)
    showAppSnack(context, 'Déconnexion réussie.');
    context.go('/preview');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            MotifHeader(
              motif: 'assets/motifs/motif_voix.png',
              title: 'Profil',
              height: 132,
              onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identity card — données réelles du compte
                    ValueListenableBuilder<UserProfile?>(
                      valueListenable: AuthSession.instance.user,
                      builder: (_, profile, _) {
                        final name = profile?.name ?? 'Contributeur';
                        final contact = profile?.phone ?? profile?.email ?? '';
                        final level = profile?.level ?? 'bronze';
                        final lvl = LevelInfo.of(level, profile?.contributionsValidated ?? 0);
                        final levelName = '${level[0].toUpperCase()}${level.substring(1)}';
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.04)],
                            ),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 58, height: 58,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE11D28), Color(0xFFB3141E)],
                                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(profile?.initials ?? '?',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                    if (contact.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(contact,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: lvl.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(lvl.icon, size: 14, color: lvl.color),
                                    const SizedBox(width: 4),
                                    Text(levelName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lvl.color)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    // Stats
                    ValueListenableBuilder<UserProfile?>(
                      valueListenable: AuthSession.instance.user,
                      builder: (_, profile, _) => Row(
                        children: [
                          Expanded(child: _StatTile(value: '${profile?.points ?? 0}', label: 'Points')),
                          const SizedBox(width: 10),
                          Expanded(child: _StatTile(value: '${profile?.contributionsValidated ?? 0}', label: 'Validées')),
                          const SizedBox(width: 10),
                          Expanded(child: _StatTile(value: _balanceText, label: 'FCFA')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('Compte',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<UserProfile?>(
                      valueListenable: AuthSession.instance.user,
                      builder: (_, profile, _) {
                        final parts = [profile?.language, profile?.dialect, profile?.region]
                            .where((s) => s != null && s.isNotEmpty)
                            .cast<String>()
                            .toList();
                        final value = parts.isEmpty ? 'Non défini' : parts.take(2).join(' · ');
                        return _SettingRow(
                          icon: Icons.translate_rounded, label: 'Langue & région', value: value,
                          onTap: () => context.go('/profile-setup'),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text('Préférences',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.05 * 12)),
                    const SizedBox(height: 10),
                    // Notifications toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text('Notifications',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                          Switch(
                            value: _notifications,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.black.withValues(alpha: 0.1),
                            onChanged: (v) => setState(() => _notifications = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingRow(icon: Icons.help_outline_rounded, label: 'Aide & support', value: '',
                      onTap: () => showAppSnack(context, 'Centre d\'aide — bientôt disponible.')),
                    const SizedBox(height: 24),
                    // Logout
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 56),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.red.withValues(alpha: 0.3), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('Se déconnecter',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.red)),
                      ),
                    ),
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

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
            if (value.isNotEmpty)
              Flexible(
                child: Text(value,
                  textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
