import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../data/api/auth_api.dart';
import '../data/prefs/dialect_prefs.dart';
import '../widgets/app_feedback.dart';
import '../widgets/progress_bar.dart';

/// Formulaire post-authentification — langue + dialecte + politique.
/// Obligatoire pour contribuer, mais skippable (accès lecture seule).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // Étapes : 0 = langue, 1 = dialecte, 2 = politique
  int _step = 0;

  // Étape 1 — Langues
  final Set<String> _langs = {};

  // Étape 2 — Dialecte
  String _dialect = '';
  String _region  = '';
  int    _rare    = 0;

  static const _languages = [
    {'name': 'Mooré',      'sub': 'Plateau Central · ~5M locuteurs', 'color': Color(0xFFE11D28), 'icon': Icons.terrain_rounded},
    {'name': 'Dioula',     'sub': 'Langue du commerce · Ouest',       'color': Color(0xFF1A9E78), 'icon': Icons.storefront_rounded},
    {'name': 'Fulfuldé',   'sub': 'Langue peule · Sahel',              'color': Color(0xFF2A5298), 'icon': Icons.pets_rounded},
    {'name': 'Gulmancema', 'sub': 'Langue du Gulmu · Est',             'color': Color(0xFF7B2D8B), 'icon': Icons.landscape_rounded},
  ];

  static const _regions = [
    {'name': 'Ouagadougou', 'zone': 'Centre',           'clips': 4230, 'pct': 0.88, 'rare': 0, 'lang': 'Mooré'},
    {'name': 'Koudougou',   'zone': 'Plateau Central',  'clips': 1840, 'pct': 0.42, 'rare': 0, 'lang': 'Mooré'},
    {'name': 'Ouahigouya',  'zone': 'Nord',              'clips': 620,  'pct': 0.15, 'rare': 1, 'lang': 'Mooré'},
    {'name': 'Yatenga',     'zone': 'Nord',              'clips': 180,  'pct': 0.05, 'rare': 2, 'lang': 'Mooré'},
    {'name': 'Bobo-Dioulasso', 'zone': 'Hauts-Bassins', 'clips': 980,  'pct': 0.24, 'rare': 0, 'lang': 'Dioula'},
    {'name': 'Dédougou',    'zone': 'Boucle du Mouhoun','clips': 340,  'pct': 0.09, 'rare': 1, 'lang': 'Dioula'},
    {'name': 'Dori',        'zone': 'Sahel',             'clips': 120,  'pct': 0.03, 'rare': 2, 'lang': 'Fulfuldé'},
    {'name': 'Fada N\'Gourma','zone': 'Est',             'clips': 290,  'pct': 0.08, 'rare': 1, 'lang': 'Gulmancema'},
  ];

  // Regions filtrées selon la langue principale
  List<Map<String, Object>> get _filteredRegions {
    if (_langs.isEmpty) return List<Map<String, Object>>.from(_regions);
    final primary = _langs.first;
    final filtered = _regions.where((r) => r['lang'] == primary).toList();
    return List<Map<String, Object>>.from(filtered.isNotEmpty ? filtered : _regions);
  }

  Future<void> _completeSetup({bool accepted = true}) async {
    final lang = _langs.isNotEmpty ? _langs.first : 'Mooré';
    final dialect = _dialect.isNotEmpty ? _dialect : 'Yatenga';
    final region = _region.isNotEmpty ? _region : 'Nord';
    await DialectPrefs.save(
      langs:           _langs.toList(),
      lang:            lang,
      dialect:         dialect,
      region:          region,
      rare:            _rare,
      profileSetupDone: true,
      consentAccepted:  accepted,
    );
    try {
      await AuthApi().saveProfile(
        language: lang, dialect: dialect, region: region, commercialConsent: accepted,
      );
    } catch (_) {
      // Le local est sauvegardé ; le gating retentera au prochain /me.
      if (mounted) {
        showAppSnack(context, 'Profil enregistré localement — synchronisation à réessayer.');
      }
    }
    if (mounted) context.go('/dashboard');
  }

  Future<void> _skip() async {
    // Mode lecture seule — profil non complété
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── En-tête ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Progress steps
                      ...List.generate(3, (i) => Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: i <= _step ? AppColors.primary : Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
                      const SizedBox(width: 12),
                      // Skip
                      GestureDetector(
                        onTap: _skip,
                        child: Text('Ignorer',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stepTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.2)),
                        const SizedBox(height: 6),
                        Text(_stepSubtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Contenu dynamique ──────────────────────────────────────────
            Expanded(child: _buildStep()),
            // ── Bouton principal ───────────────────────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Quelle(s) langue(s)\nparlez-vous ?';
      case 1: return 'Votre région\nau Burkina Faso ?';
      default: return 'Votre voix,\nvotre droit';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 0: return 'Sélectionnez toutes vos langues';
      case 1: return 'Choisissez la zone où vous parlez cette langue';
      default: return 'Vos enregistrements pourront être utilisés à des fins commerciales pour améliorer les IA vocales.';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildLangStep();
      case 1: return _buildDialectStep();
      default: return _buildConsentStep();
    }
  }

  // ── Étape 1 : Langue ────────────────────────────────────────────────────

  Widget _buildLangStep() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _languages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final l = _languages[i];
        final name = l['name'] as String;
        final isSelected = _langs.contains(name);
        final color = l['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() {
            if (isSelected) { _langs.remove(name); } else { _langs.add(name); }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.08) : AppColors.surface,
              border: isSelected ? Border.all(color: color, width: 2) : Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(l['icon'] as IconData, size: 24, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: isSelected ? color : AppColors.textPrimary)),
                      Text(l['sub'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Étape 2 : Région/dialecte ────────────────────────────────────────────

  Widget _buildDialectStep() {
    final regions = _filteredRegions;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: regions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = regions[i];
        final name = r['name'] as String;
        final zone = r['zone'] as String;
        final clips = r['clips'] as int;
        final pct   = r['pct']  as double;
        final rare  = r['rare'] as int;
        final isSelected = _dialect == name;

        return GestureDetector(
          onTap: () => setState(() {
            _dialect = name;
            _region  = zone;
            _rare    = rare;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isSelected)
                      Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    Expanded(child: Text(name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                      child: Text(zone, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ),
                    if (rare > 0) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.star_rounded, size: 12, color: rare == 2 ? AppColors.primary : AppColors.yellow),
                      const SizedBox(width: 3),
                      Text(rare == 2 ? 'Très rare' : 'Rare',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: rare == 2 ? AppColors.primary : AppColors.yellow)),
                    ],
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Container(width: 22, height: 22,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.check, size: 12, color: Colors.white)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                AppProgressBar(value: pct, height: 6, color: AppColors.primary),
                const SizedBox(height: 4),
                Text('$clips clips · ${pct < 0.1 ? "Très peu couvert" : pct < 0.3 ? "Peu couvert" : "Couvert"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Étape 3 : Politique ──────────────────────────────────────────────────

  Widget _buildConsentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description_rounded, size: 26, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(child: Text('Politique d\'utilisation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                  ],
                ),
                const SizedBox(height: 16),
                _ConsentPoint(
                  icon: Icons.mic_rounded,
                  title: 'Vos enregistrements audio',
                  body: 'Les clips que vous enregistrez peuvent être utilisés pour entraîner des modèles d\'intelligence artificielle à des fins commerciales.',
                ),
                const SizedBox(height: 12),
                _ConsentPoint(
                  icon: Icons.menu_book_rounded,
                  title: 'Vos connaissances linguistiques',
                  body: 'Les transcriptions et validations que vous fournissez peuvent être intégrées dans des bases de données linguistiques et revendues à des partenaires.',
                ),
                const SizedBox(height: 12),
                _ConsentPoint(
                  icon: Icons.payments_rounded,
                  title: 'Votre rémunération',
                  body: 'En contrepartie, vous êtes rémunéré via le système de points, convertibles en argent réel (FCFA) via Mobile Money.',
                ),
                const SizedBox(height: 12),
                _ConsentPoint(
                  icon: Icons.lock_rounded,
                  title: 'Vos droits',
                  body: 'Vous pouvez retirer votre consentement à tout moment depuis votre profil. Les données déjà collectées restent dans la base.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cette politique ne s\'affiche qu\'une seule fois. Vous ne serez plus jamais interrompu pendant vos enregistrements.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    if (_step == 2) {
      // Étape politique — deux boutons
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _completeSetup(accepted: true),
              child: Container(
                width: double.infinity, height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE11D28), Color(0xFF9B0000)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('J\'accepte et je commence',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _skip,
              child: const Text(
                'Continuer sans accepter (consultation seulement)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Étapes 0 et 1 — bouton Suivant
    final canNext = _step == 0 ? _langs.isNotEmpty : _dialect.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: GestureDetector(
        onTap: canNext ? () => setState(() => _step++) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity, height: 54,
          decoration: BoxDecoration(
            color: canNext ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(_step == 1 ? 'Continuer →' : 'Suivant →',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _ConsentPoint({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
