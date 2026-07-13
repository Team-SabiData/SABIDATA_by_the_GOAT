import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_body.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/progress_ring.dart';
import '../widgets/spring_tap.dart';
import '../widgets/state_views.dart';
import '../data/api/api_client.dart';
import '../data/api/validation_api.dart';
import '../data/api/api_exception.dart';
import '../data/gamification/local_stats.dart';

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final _api = ValidationApi();
  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? _clip;
  bool _loading = true;
  bool _empty = false;
  String? _error;
  int _todayValidations = 0;

  Uint8List? _bytes; // cache du clip courant
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _fetchNext();
    _loadToday();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    final n = await LocalStats().todayValidations();
    if (mounted) setState(() => _todayValidations = n);
  }

  // Télécharge le clip courant (audioUrl de /validation/next) une seule
  // fois par clip et le joue ; pause si déjà en lecture.
  Future<void> _togglePlay() async {
    final url = _clip?['audioUrl'] as String?;
    if (url == null) {
      showAppSnack(context, 'Aucun audio pour ce clip.');
      return;
    }
    if (_playing) {
      await _player.pause();
      return;
    }
    try {
      _bytes ??= await ApiClient().getBytes(url);
      await _player.play(BytesSource(_bytes!));
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  // GET /api/validation/next — null (204) = file vide.
  Future<void> _fetchNext() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clip = await _api.next();
      if (!mounted) return;
      setState(() {
        _clip = clip;
        _bytes = null;
        _pos = Duration.zero;
        _dur = Duration.zero;
        _empty = clip == null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  // POST /api/clips/:id/validations {verdict}
  Future<void> _vote(String verdict, String label) async {
    final clip = _clip;
    if (clip == null) return;
    try {
      await _api.submitVerdict(clip['clipId'] as String, verdict);
      await LocalStats().recordValidation();
      await _loadToday();
      if (verdict == 'correct' && mounted) {
        showCelebration(context, points: 20);
      } else if (mounted) {
        showAppSnack(context, label);
      }
      await _fetchNext();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  /// Identifiant de clip abrégé, sûr quelle que soit sa longueur
  /// (les IDs in-memory de dev sont courts, ex. « c_3 »).
  String get _shortClipId {
    final id = (_clip?['clipId'] as String?) ?? '';
    if (id.isEmpty) return '—';
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 24, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => context.canPop() ? context.pop() : context.go('/dashboard')),
                  const Expanded(child: Center(
                    child: Text('Validation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  )),
                  ProgressRing(
                    value: _todayValidations / 20, // objectif indicatif journalier
                    size: 40,
                    stroke: 4,
                    color: AppColors.green,
                    center: Text('$_todayValidations', style: AppText.numeric(13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppLoadingState(label: 'Chargement du prochain clip…')
                  : _error != null
                      ? AppErrorState(message: _error!, onAction: _fetchNext)
                      : _empty
                          ? AppEmptyState(
                              icon: Icons.check_circle_rounded,
                              title: 'File vide',
                              message: 'Aucun enregistrement à valider pour votre niveau. Revenez plus tard.',
                              actionLabel: 'Retour à l\'accueil',
                              onAction: () => context.go('/dashboard'),
                            )
                          : SingleChildScrollView(
                child: Column(
                  children: [
            const SizedBox(height: 16),
            // Phrase source card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phrase source (français)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.08 * 11)),
                  const SizedBox(height: 8),
                  const Text('"La saison des pluies commence en mai."',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.translate_rounded, size: 15, color: AppColors.green),
                          SizedBox(width: 4),
                          Text('Mooré', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text('· clip $_shortClipId · ${_clip?['durationS'] ?? '–'}s',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Audio player
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppCard(
                child: Row(
                  children: [
                    SpringTap(
                      onTap: _togglePlay,
                      child: Semantics(
                        button: true,
                        label: _playing ? 'Mettre en pause' : "Écouter l'enregistrement",
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(AppRadius.button),
                            boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
                          ),
                          child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Écouter l'enregistrement",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: _dur.inMilliseconds == 0
                                  ? 0
                                  : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.hairline,
                              color: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dur.inMilliseconds == 0
                          ? '0:00'
                          : '${_pos.inMinutes.toString().padLeft(2, '0')}:${(_pos.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: AppText.numeric(13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Cet enregistrement correspond-il à la phrase ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
            const SizedBox(height: 14),
            // Verdict buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _VerdictButton(
                    color: AppColors.green,
                    icon: Icons.check,
                    label: "Oui, c'est correct",
                    reward: '+20 pts',
                    onTap: () => _vote('correct', '+20 pts gagnés'),
                  ),
                  const SizedBox(height: 10),
                  _VerdictButton(
                    color: AppColors.red,
                    icon: Icons.close,
                    label: 'Non, il y a un problème',
                    onTap: () => _vote('problem', 'Signalement enregistré, merci'),
                  ),
                  const SizedBox(height: 10),
                  _VerdictButton(
                    color: AppColors.textSecondary,
                    icon: Icons.help_outline,
                    label: "Je ne suis pas sûr(e)",
                    onTap: () => _vote('unsure', 'Passé au clip suivant'),
                  ),
                ],
              ),
            ),
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

class _VerdictButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String? reward;
  final VoidCallback onTap;

  const _VerdictButton({
    required this.color, required this.icon, required this.label,
    this.reward, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              // badge d'icône : rayon dédié plus petit que AppRadius.button
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            ),
            if (reward != null)
              Text(reward!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
