import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';
import '../data/api/api_client.dart';
import '../data/api/api_exception.dart';
import '../data/api/transcription_api.dart';

/// Transcrire un clip validé de sa propre langue : écouter l'audio, écrire ce
/// qui est dit, soumettre. File servie et filtrée par langue/dialecte côté serveur.
class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final _api = TranscriptionApi();
  final _controller = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  Map<String, dynamic>? _clip;
  bool _loading = true;
  bool _empty = false;
  bool _submitting = false;
  String? _error;

  Uint8List? _bytes;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final List<StreamSubscription> _subs = [];

  static const _specialChars = ['ɛ', 'ɔ', 'ŋ', 'ɩ', 'ʋ', 'ɛ́', 'ɛ̀', 'ó', '⌫'];
  static const _toneChars = ['ɛ́', 'ɛ̀', 'ó'];

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
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = _clip?['audioUrl'] as String?;
    if (url == null) return;
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

  Future<void> _fetchNext() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _controller.clear();
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

  Future<void> _submit() async {
    final clip = _clip;
    final text = _controller.text.trim();
    if (clip == null) return;
    if (text.isEmpty) {
      showAppSnack(context, 'Écrivez la transcription avant d\'envoyer.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _api.submit(clip['clipId'] as String, text);
      if (mounted) showCelebration(context, points: (res['reward'] as num?)?.toInt() ?? 80);
      await _fetchNext();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _insertChar(String char) {
    if (char == '⌫') {
      final text = _controller.text;
      if (text.isNotEmpty) _controller.text = text.substring(0, text.length - 1);
    } else {
      _controller.text += char;
    }
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(1, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

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
                  const SizedBox(width: 4),
                  const Text('Transcrire',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppLoadingState(label: 'Chargement du prochain clip…')
                  : _error != null
                      ? AppErrorState(message: _error!, onAction: _fetchNext)
                      : _empty
                          ? const AppEmptyState(
                              icon: Icons.edit_note_rounded,
                              title: 'Rien à transcrire',
                              message: 'Aucun clip validé dans votre langue pour le moment. Revenez plus tard !',
                            )
                          : _buildContent(),
            ),
            if (!_loading && _error == null && !_empty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: PrimaryButton(
                  label: _submitting ? 'Envoi…' : 'Soumettre',
                  color: AppColors.blue,
                  textColor: Colors.white,
                  enabled: !_submitting,
                  onTap: _submit,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Lecteur audio du clip à transcrire
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Écoutez et transcrivez ce que vous entendez',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.04 * 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 5))],
                        ),
                        child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: _dur.inMilliseconds == 0 ? 0 : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.hairline,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_dur.inMilliseconds == 0 ? '0:00' : _fmt(_pos), style: AppText.numeric(13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Zone de transcription
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Votre transcription',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04 * 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(minHeight: 100),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.25), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.7),
                    decoration: const InputDecoration.collapsed(
                        hintText: 'Écrivez ce qui est dit…', hintStyle: TextStyle(color: AppColors.textSecondary)),
                    maxLines: null,
                    cursorColor: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Caractères spéciaux
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Caractères spéciaux',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04 * 12)),
                const SizedBox(height: 8),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
