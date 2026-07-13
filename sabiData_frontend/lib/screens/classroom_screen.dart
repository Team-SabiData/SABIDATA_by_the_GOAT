import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../widgets/app_feedback.dart';
import '../widgets/primary_button.dart';
import '../widgets/gold_thread.dart';
import '../widgets/state_views.dart';
import '../data/api/classroom_api.dart';
import '../data/api/api_exception.dart';

/// Classroom — groupe de collecte (école, association) rejoint par CODE
/// d'invitation. Les contributions des membres alimentent des stats de groupe.
class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  final _api = ClassroomApi();
  Map<String, dynamic>? _classroom;
  bool _loading = true;
  bool _error = false; // échec de chargement (ex. hors-ligne) ≠ pas de classroom
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final cls = await _api.mine();
      if (mounted) setState(() { _classroom = cls; _loading = false; });
    } catch (_) {
      // Réseau/serveur indisponible : on ne sait pas si l'utilisateur a un
      // classroom → état d'erreur (pas la vue « créer/rejoindre »).
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  Future<void> _create(String name, String desc) async {
    setState(() => _busy = true);
    try {
      final cls = await _api.create(name, desc);
      if (mounted) setState(() => _classroom = cls);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join(String code) async {
    setState(() => _busy = true);
    try {
      final cls = await _api.join(code);
      if (mounted) {
        setState(() => _classroom = cls);
        showAppSnack(context, 'Vous avez rejoint « ${cls['name']} »');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    setState(() => _busy = true);
    try {
      await _api.leave();
      if (mounted) setState(() => _classroom = null);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: Column(
          children: [
            MotifHeader(
              motif: 'assets/motifs/motif_dialecte.png',
              title: 'Classroom',
              height: 128,
              scrim: const Color(0xFF07223B),
              onBack: () => context.canPop() ? context.pop() : context.go('/dashboard'),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error
                      ? AppErrorState(
                          message: 'Impossible de charger votre classroom. Vérifiez votre connexion.',
                          onAction: _load,
                        )
                      : _classroom == null
                          ? _buildEmpty()
                          : _buildMine(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Aucun classroom : créer ou rejoindre ──────────────────────────────────
  Widget _buildEmpty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school_rounded, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('Rejoignez un groupe de collecte', style: AppText.display(22)),
          const SizedBox(height: 6),
          const GoldThread(),
          const SizedBox(height: 12),
          const Text(
            'Un classroom rassemble une école, une association ou une coopérative autour d\'un objectif commun. '
            'Vos contributions sont cumulées pour le groupe. Rejoignez-en un avec un code, ou créez le vôtre.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Rejoindre avec un code',
            icon: Icons.vpn_key_rounded,
            enabled: !_busy,
            onTap: _showJoinDialog,
          ),
          const SizedBox(height: 12),
          _outlineButton('Créer un classroom', Icons.add_rounded, _busy ? null : _showCreateDialog),
        ],
      ),
    );
  }

  // ── Mon classroom : code, stats, membres ──────────────────────────────────
  Widget _buildMine() {
    final c = _classroom!;
    final code = c['inviteCode']?.toString() ?? '——';
    final members = (c['members'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['name']?.toString() ?? 'Classroom', style: AppText.display(24)),
          if ((c['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(c['description'].toString(), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),
          // Code d'invitation à partager
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0E3A63), Color(0xFF07223B)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CODE D\'INVITATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(code, style: AppText.numeric(30, color: Colors.white).copyWith(letterSpacing: 4)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        showAppSnack(context, 'Code copié — partagez-le pour inviter des membres.');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Copier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Stats de groupe
          Row(
            children: [
              _stat('${c['memberCount'] ?? 0}', 'Membres'),
              const SizedBox(width: 10),
              _stat('${c['clipCount'] ?? 0}', 'Clips'),
              const SizedBox(width: 10),
              _stat('${c['groupPoints'] ?? 0}', 'Points'),
            ],
          ),
          const SizedBox(height: 22),
          Text('Membres', style: AppText.display(15)),
          const SizedBox(height: 10),
          ...members.asMap().entries.map((e) => _memberRow(e.key + 1, e.value)),
          const SizedBox(height: 24),
          _outlineButton('Quitter le classroom', Icons.logout_rounded, _busy ? null : _leave, danger: true),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Text(value, style: AppText.numeric(22)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _memberRow(int rank, Map<String, dynamic> m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('$rank', style: AppText.numeric(14, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            Expanded(child: Text(m['name']?.toString() ?? '—',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            Text('${m['points'] ?? 0} pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback? onTap, {bool danger = false}) {
    final color = danger ? AppColors.red : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Dialogues ──────────────────────────────────────────────────────────────
  void _showJoinDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rejoindre un classroom', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Code d\'invitation (ex. ABC234)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final code = ctrl.text.trim();
              Navigator.pop(dctx);
              if (code.isNotEmpty) _join(code);
            },
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Créer un classroom', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Nom (école, association…)')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'Description (optionnel)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              Navigator.pop(dctx);
              if (name.length >= 3) {
                _create(name, descCtrl.text.trim());
              } else {
                showAppSnack(context, 'Le nom doit faire au moins 3 caractères.');
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }
}
