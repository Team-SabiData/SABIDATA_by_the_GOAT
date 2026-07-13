import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';

/// Tâche de conversion Bronze → Or (recherche métier doc 2).
///
/// Un contributeur `standard` reçoit l'audio + la transcription phonétique
/// cohérente déjà produite, et la réécrit en orthographe officielle. On
/// réutilise le travail au lieu de repartir de zéro → la donnée monte de tier.
/// Intention backend : POST /transcriptions {target_id, text, writing_system:std,
/// parent_transcription_id} qui repasse par le calcul de tier.
class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  // Transcription phonétique source (tier Bronze) — lecture seule.
  static const _phonetic = 'keere wa, sigida be se ka ke jo';
  final _controller = TextEditingController();
  bool _submitted = false;

  static const _specialChars = ['ɛ', 'ɔ', 'ŋ', 'ɩ', 'ʋ', 'ɛ́', 'ɛ̀', 'ó', '⌫'];
  static const _toneChars = ['ɛ́', 'ɛ̀', 'ó'];

  bool get _isValid => _controller.text.trim().isNotEmpty;

  void _insertChar(String char) {
    if (char == '⌫') {
      final t = _controller.text;
      if (t.isNotEmpty) _controller.text = t.substring(0, t.length - 1);
    } else {
      _controller.text += char;
    }
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    setState(() {});
  }

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

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: AppBody(
          child: AppEmptyState(
            icon: Icons.workspace_premium_rounded,
            title: 'Conversion soumise !',
            message: 'La transcription passe en orthographe standard. Après relecture, elle pourra atteindre le tier Or. +120 points.',
            actionLabel: 'Continuer',
            onAction: () => context.go('/expert'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 24, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => context.canPop() ? context.pop() : context.go('/expert')),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.orange.withValues(alpha: 0.18), AppColors.primary.withValues(alpha: 0.18)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Conversion Bronze → Or',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // équilibre le bouton retour
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Audio
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => showAppSnack(context, 'Lecture de l\'audio source…'),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.play_arrow, color: AppColors.bg, size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text('Audio original · Mooré · 0:06',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Phonetic source (read-only)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transcription phonétique (Bronze) — à convertir',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange, letterSpacing: 0.06 * 11)),
                          SizedBox(height: 8),
                          Text('"$_phonetic"',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Standard output
                    const Text('Réécrivez en orthographe standard',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04 * 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(minHeight: 90),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.7),
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Version officielle…',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                        ),
                        maxLines: null,
                        cursorColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Special keyboard
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14)),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _specialChars.map((char) {
                          final isTone = _toneChars.contains(char);
                          return GestureDetector(
                            onTap: () => _insertChar(char),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                              child: Center(
                                child: Text(char,
                                  style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600,
                                    color: isTone ? AppColors.blue : (char == '⌫' ? AppColors.textSecondary : AppColors.textPrimary),
                                  )),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: PrimaryButton(
                label: 'Soumettre → +120 pts',
                enabled: _isValid,
                onTap: () => setState(() => _submitted = true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
