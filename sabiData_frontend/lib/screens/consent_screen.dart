import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_body.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/spring_tap.dart';

/// Capture du consentement & de la licence — décision 4 (chaîne légale immuable).
///
/// Porte d'entrée du flux de contribution : on capture AVANT l'enregistrement
/// le consentement explicite, la compatibilité usage commercial et la
/// provenance. Le choix est attaché à chaque clip à sa création
/// (POST /clips → commercial_use, consent_version, license_tag immuables).
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  static const _consentVersion = 'v1';
  bool _commercial = true; // valeur par défaut (maximise la valeur du dataset)
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 24, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => context.canPop() ? context.pop() : context.go('/dashboard')),
                  const SizedBox(width: 4),
                  const Text('Avant d\'enregistrer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: const Center(
                        child: Icon(Icons.record_voice_over_rounded,
                            size: 30, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Votre voix, vos droits',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.25)),
                    const SizedBox(height: 10),
                    const Text(
                      'Vos enregistrements aident à bâtir un jeu de données ouvert pour préserver les langues nationales. Ils pourront être partagés et publiés à des fins de recherche et de technologie linguistique.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    // Provenance (auto-capturée, immuable)
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ClauseIcon(icon: Icons.mic_rounded, color: AppColors.primary),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Informations enregistrées avec votre clip',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const _ProvenanceRow(icon: Icons.phone_iphone_rounded, label: 'Appareil', value: 'Mobile · SabiData'),
                          const _ProvenanceRow(icon: Icons.translate_rounded, label: 'Langue', value: 'Mooré'),
                          const _ProvenanceRow(icon: Icons.calendar_today_rounded, label: 'Date', value: "Aujourd'hui"),
                          _ProvenanceRow(icon: Icons.description_rounded, label: 'Conditions', value: 'Licence $_consentVersion'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Usage commercial
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _ClauseIcon(icon: Icons.payments_rounded, color: AppColors.gold),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Autoriser l\'usage commercial',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                SizedBox(height: 3),
                                Text('Permet d\'inclure vos clips dans des jeux de données vendus, augmentant vos revenus potentiels.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: _commercial,
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primarySoft,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.border,
                            onChanged: (v) => setState(() => _commercial = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Acceptation explicite
                    _AcceptanceCard(
                      onTap: () => setState(() => _accepted = !_accepted),
                      accepted: _accepted,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: PrimaryButton(
                  label: 'Accepter et enregistrer →',
                  enabled: _accepted,
                  onTap: () => context.go('/recording', extra: {
                    'commercial': _commercial,
                    'consent_version': _consentVersion,
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône ronde de tête de clause — style Material rounded uniforme.
class _ClauseIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _ClauseIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      // badge d'icône : rayon dédié plus petit que AppRadius.button
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Clause d'acceptation explicite — carte scannable avec case à cocher.
class _AcceptanceCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool accepted;
  const _AcceptanceCard({required this.onTap, required this.accepted});

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClauseIcon(icon: Icons.shield_rounded, color: AppColors.green),
            const SizedBox(width: 12),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Je comprends et j\'accepte que mes enregistrements soient collectés selon ces conditions.',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5)),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: accepted ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: accepted ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvenanceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProvenanceRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
