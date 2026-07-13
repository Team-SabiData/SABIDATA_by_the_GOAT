import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_body.dart';
import '../widgets/primary_button.dart';
import '../data/prefs/dialect_prefs.dart';

class SkillProfileScreen extends StatefulWidget {
  const SkillProfileScreen({super.key});

  @override
  State<SkillProfileScreen> createState() => _SkillProfileScreenState();
}

class _SkillProfileScreenState extends State<SkillProfileScreen> {
  bool _canSpeak = true;
  bool _canRead = false;
  // 0=Non, 1=Phonétique, 2=Standard
  int _writeLevel = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            // TODO(Task 11): en-tête d'étape à revoir avec le redesign de cet écran.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppBackButton(onTap: () => context.canPop() ? context.pop() : context.go('/language-select')),
                  Row(
                    children: List.generate(
                      3,
                      (i) => Container(
                        width: 28,
                        height: 4,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i == 1 ? AppColors.primary : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Language badge
            Container(
              margin: const EdgeInsets.fromLTRB(28, 18, 28, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.05)],
                ),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, size: 28, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Langue en cours', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 0.05 * 12)),
                      const Text('Mooré', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 16, 28, 12),
              child: Text('Pour le Mooré, vous pouvez…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Speak toggle
                  _ToggleRow(
                    icon: Icons.mic_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primary.withValues(alpha: 0.12),
                    label: 'Parler',
                    subtitle: "S'exprimer oralement",
                    value: _canSpeak,
                    onChanged: (v) => setState(() => _canSpeak = v),
                  ),
                  const SizedBox(height: 10),
                  // Read toggle
                  _ToggleRow(
                    icon: Icons.visibility_rounded,
                    iconColor: AppColors.green,
                    iconBg: AppColors.green.withValues(alpha: 0.1),
                    label: 'Lire',
                    subtitle: 'Lire des textes en mooré',
                    value: _canRead,
                    onChanged: (v) => setState(() => _canRead = v),
                  ),
                  const SizedBox(height: 10),
                  // Write 3-way
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Icon(Icons.edit_rounded, size: 22, color: AppColors.blue)),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Écrire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                SizedBox(height: 1),
                                Text("Compétence d'écriture", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _WriteOption(label: 'Non', selected: _writeLevel == 0, onTap: () => setState(() => _writeLevel = 0)),
                            const SizedBox(width: 8),
                            _WriteOption(label: 'Phonétique', selected: _writeLevel == 1, onTap: () => setState(() => _writeLevel = 1)),
                            const SizedBox(width: 8),
                            _WriteOption(label: 'Standard', selected: _writeLevel == 2, onTap: () => setState(() => _writeLevel = 2)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Info box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.blue.withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                              children: [
                                TextSpan(text: 'Standard officiel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                TextSpan(text: ' — utilise des caractères spéciaux : ɛ, ɩ, ʋ, ɔ et marques de tons.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
              child: PrimaryButton(
                label: 'Continuer →',
                onTap: () async {
                  await DialectPrefs.save(writeLevel: _writeLevel);
                  if (context.mounted) context.go('/dialect-region');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Icon(icon, size: 22, color: iconColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52, height: 30,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    top: 3,
                    left: value ? 25 : 3,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: value ? Colors.white : Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                      ),
                    ),
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

class _WriteOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WriteOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.07),
            border: selected ? Border.all(color: AppColors.blue, width: 1.5) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.blue : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
