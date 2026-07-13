import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/primary_button.dart';
import '../widgets/spring_tap.dart';
import '../widgets/state_views.dart';
import '../data/api/contribution_api.dart';
import '../data/api/api_exception.dart';
import '../data/gamification/local_stats.dart';
import '../data/prefs/dialect_prefs.dart';
import '../data/outbox/outbox_service.dart';

/// Revue de l'enregistrement avant soumission : réécouter / refaire / soumettre.
/// Remplace l'ancien `pop()` qui jetait l'audio. [duration] vient de l'écran
/// d'enregistrement via `extra`. Intention backend : POST /clips (multipart).
class RecordingReviewScreen extends StatefulWidget {
  final String? duration;
  final bool commercialUse;
  final String? audioPath;

  const RecordingReviewScreen({super.key, this.duration, this.commercialUse = true, this.audioPath});

  @override
  State<RecordingReviewScreen> createState() => _RecordingReviewScreenState();
}

class _RecordingReviewScreenState extends State<RecordingReviewScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _submitting = false;
  Map<String, dynamic>? _result;

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
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final path = widget.audioPath;
    if (path == null) {
      showAppSnack(context, 'Aucun enregistrement à lire.');
      return;
    }
    if (_playing) {
      await _player.pause();
    } else if (_pos > Duration.zero && _pos < _dur) {
      await _player.resume();
    } else {
      await _player.play(DeviceFileSource(path));
    }
  }

  int get _durationSeconds {
    final parts = (widget.duration ?? '00:05').split(':');
    if (parts.length != 2) return 5;
    final m = int.tryParse(parts[0]) ?? 0;
    final s = int.tryParse(parts[1]) ?? 5;
    return m * 60 + s;
  }

  Future<void> _submit() async {
    final path = widget.audioPath;
    if (path == null) {
      showAppSnack(context, 'Enregistrement introuvable, refaites la prise.');
      return;
    }
    setState(() => _submitting = true);
    try {
      // POST /api/clips → auto-check → peer_review (+ ledger provisoire) | rejected.
      // Rareté + langue/dialecte/région issus du profil (classification en BD).
      final res = await ContributionApi().submitClip(
        rarity: DialectPrefs.rare,
        durationS: _durationSeconds,
        commercialUse: widget.commercialUse,
        consentVersion: 'v1',
        audioPath: path,
        language: DialectPrefs.primaryLang,
        dialect: DialectPrefs.dialect,
        region: DialectPrefs.region,
      );
      if (mounted) setState(() => _result = res);
      if (mounted && res['status'] != 'rejected') {
        await LocalStats().recordSubmission();
        if (mounted) showCelebration(context, points: (res['reward'] as num?)?.toInt() ?? 150);
      }
    } on ApiException catch (e) {
      if (e.statusCode == null) {
        // Réseau indisponible → mise en file ; envoi auto au retour de la connexion.
        await OutboxService.instance.enqueue(
          audioPath: path,
          rarity: DialectPrefs.rare,
          durationS: _durationSeconds,
          commercialUse: widget.commercialUse,
          consentVersion: 'v1',
          language: DialectPrefs.primaryLang,
          dialect: DialectPrefs.dialect,
          region: DialectPrefs.region,
        );
        await LocalStats().recordSubmission();
        if (mounted) {
          showAppSnack(context, 'Hors ligne — enregistrement mis en file, envoyé au retour du réseau.');
          context.go('/dashboard');
        }
      } else if (mounted) {
        showAppSnack(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    if (res != null) {
      final rejected = res['status'] == 'rejected';
      final reward = res['reward'] ?? 0;
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: AppBody(
          child: AppEmptyState(
            icon: rejected ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            title: rejected ? 'Enregistrement non retenu' : 'Enregistrement envoyé !',
            message: rejected
                ? 'La vérification automatique a échoué (durée hors limites). Réessayez avec un clip plus long.'
                : 'Merci pour votre contribution. +$reward points · il passe en validation par la communauté.',
            actionLabel: rejected ? 'Réessayer' : 'Continuer',
            onAction: () => context.go(rejected ? '/recording' : '/dashboard'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            MotifHeader(
              motif: 'assets/motifs/motif_voix.png',
              title: 'Vérifier',
              height: 128,
              onBack: () => context.go('/recording'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Réécoutez avant d\'envoyer',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('Vérifiez que votre voix est claire et correspond à la phrase.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                    const SizedBox(height: 18),
                    // Phrase card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card)),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Phrase enregistrée · Mooré',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.08 * 11)),
                          SizedBox(height: 10),
                          Text('"Le marché se tient chaque dimanche matin."',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Playback card
                    AppCard(
                      child: Row(
                        children: [
                          SpringTap(
                            onTap: _togglePlay,
                            child: Semantics(
                              button: true,
                              label: _playing
                                  ? 'Mettre en pause'
                                  : 'Écouter mon enregistrement',
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  boxShadow: [BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 16, offset: const Offset(0, 6))],
                                ),
                                child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: LinearProgressIndicator(
                                value: _dur.inMilliseconds == 0
                                    ? 0
                                    : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: AppColors.hairline,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _dur.inMilliseconds == 0
                                ? (widget.duration ?? '00:00')
                                : '${_pos.inMinutes.toString().padLeft(2, '0')}:${(_pos.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: AppText.numeric(14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Licence attachée au clip (consentement capturé, immuable)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.18)),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_rounded, size: 16, color: AppColors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.commercialUse
                                  ? 'Licence v1 · usage commercial autorisé'
                                  : 'Licence v1 · usage non commercial uniquement',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.go('/recording', extra: {
                        'commercial': widget.commercialUse,
                        'consent_version': 'v1',
                      }),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1.5),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 6),
                            Text('Refaire',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: _submitting ? 'Envoi…' : 'Soumettre',
                      enabled: !_submitting,
                      onTap: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
