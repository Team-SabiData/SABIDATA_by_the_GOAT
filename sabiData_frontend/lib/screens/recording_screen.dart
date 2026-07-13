import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/patterns.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../data/api/api_client.dart';
import '../data/prefs/dialect_prefs.dart';

class RecordingScreen extends StatefulWidget {
  final bool commercialUse;
  final String consentVersion;

  const RecordingScreen({super.key, this.commercialUse = true, this.consentVersion = 'v1'});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  final AudioRecorder _recorder = AudioRecorder();
  final List<double> _levels = List.filled(24, 0.05, growable: false);
  StreamSubscription<Amplitude>? _ampSub;
  String? _audioPath;
  bool _isRecording = true;
  int _seconds = 0;

  // Phrase dynamique chargée depuis l'API
  String _promptText = 'Chargement…';
  bool   _loadingPrompt = true;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _startRecording();
    _fetchPrompt();
  }

  Future<void> _fetchPrompt() async {
    try {
      final lang = Uri.encodeComponent(DialectPrefs.primaryLang);
      final data = await _api.get('/api/prompts/next?lang=$lang') as Map;
      final p = data['prompt'] as Map? ?? {};
      if (mounted) {
        setState(() {
          _promptText    = p['text']?.toString() ?? 'Enregistrez cette phrase.';
          _loadingPrompt = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingPrompt = false; });
    }
  }

  Future<void> _startRecording() async {
    // Vérifier si la permission a déjà été accordée (mémorisée)
    final prefs = await SharedPreferences.getInstance();
    final alreadyGranted = prefs.getBool('mic_granted') ?? false;

    if (!alreadyGranted) {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        await prefs.setBool('mic_granted', true);
      } else {
        if (mounted) showAppSnack(context, 'Autorisation micro refusée.');
        return;
      }
    } else if (!await _recorder.hasPermission()) {
      // Précaution : la permission système a pu être révoquée manuellement
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) showAppSnack(context, 'Autorisation micro requise.');
        return;
      }
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _audioPath = path;
    _startTimer();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
      // amp.current est en dBFS (~ -45 silence → 0 max) ; normaliser 0..1
      final v = ((amp.current + 45) / 45).clamp(0.05, 1.0);
      setState(() {
        for (var i = 0; i < _levels.length - 1; i++) {
          _levels[i] = _levels[i + 1];
        }
        // lissage : moyenne avec la valeur précédente
        _levels[_levels.length - 1] = (v + _levels[_levels.length - 2]) / 2;
      });
    });
  }

  void _startTimer() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isRecording) setState(() => _seconds++);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _time => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            // Nav bar with REC indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 24, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => context.canPop() ? context.pop() : context.go('/dashboard')),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('REC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(_time, style: AppText.numeric(24)),
                ],
              ),
            ),
            const PatternBand(height: 24, color: AppColors.red, opacity: 0.06),
            const SizedBox(height: 16),
            // Phrase card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phrase à enregistrer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.08 * 11)),
                  const SizedBox(height: 10),
                  Text(
                    _loadingPrompt
                        ? '…'
                        : '"$_promptText"',
                    style: AppText.display(22)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.translate_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Enregistrez en ${DialectPrefs.primaryLang}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showAppSnack(context, 'Lecture de l\'exemple audio…'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.textSecondary),
                              SizedBox(width: 4),
                              Text('Écouter', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Waveform
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.card)),
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _levels.map((v) => Container(
                    width: 4,
                    height: 8 + 44 * v,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )).toList(),
                ),
              ),
            ),
            // Stop button
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      setState(() => _isRecording = false);
                      await _ampSub?.cancel();
                      final path = await _recorder.stop();
                      if (!context.mounted) return;
                      context.go('/recording-review', extra: {
                        'audio_path': path ?? _audioPath,
                        'duration': _time,
                        'commercial': widget.commercialUse,
                        'consent_version': widget.consentVersion,
                      });
                    },
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = _pulseController.value;
                        return SizedBox(
                          width: 120, height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: 1.0 + pulse * 1.0,
                                child: Opacity(
                                  opacity: (1 - pulse) * 0.3,
                                  child: Container(width: 96, height: 96,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red.withValues(alpha: 0.3))),
                                ),
                              ),
                              Hero(
                                tag: 'record-cta',
                                child: Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.red,
                                    boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Appuyez pour arrêter', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 44),
              child: GestureDetector(
                onTap: () async {
                  await _ampSub?.cancel();
                  await _recorder.stop();
                  if (context.mounted) context.pop();
                },
                child: const Text('Annuler sans pénalité',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
