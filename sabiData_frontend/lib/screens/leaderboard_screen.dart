import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../data/api/api_client.dart';
import '../data/auth/auth_session.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _tab = 0;
  static const _tabs = ['Ma commune', 'Région', 'National'];

  // Données chargées depuis l'API
  List<Map<String, dynamic>> _top10 = [];
  Map<String, dynamic>? _me;
  bool _loading = true;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await _api.get('/api/leaderboard') as Map;
      if (mounted) {
        setState(() {
          _top10   = List<Map<String, dynamic>>.from(
              (data['top10'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
          _me      = data['me'] != null
              ? Map<String, dynamic>.from(data['me'] as Map)
              : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "1240" → "1 240 pts"
  String _fmtPts(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return '${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} pts';
  }

  /// "Adama Ouédraogo" → "Adama O."
  String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first} ${parts.last[0]}.';
    return name;
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
              title: 'Classement',
              subtitle: 'Mis à jour ce matin',
              height: 150,
              onBack: () => context.go('/dashboard'),
            ),
            const SizedBox(height: 16),
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final active = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? AppColors.surfaceElevated : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _tabs[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                              color: active ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Contenu principal
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_tab == 2) ...[
              // Podium — top 3
              if (_top10.length >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PodiumPlace(
                        rank: 2,
                        name: _shortName(_top10[1]['name']?.toString() ?? ''),
                        points: _fmtPts(_top10[1]['points']),
                        gradientColors: [const Color(0xFF9BA3B5), const Color(0xFFC2C8D4)],
                        barColor: const Color(0xFF9BA3B5), barHeight: 56, badgeSize: 44,
                      ),
                      _PodiumPlace(
                        rank: 1,
                        name: _shortName(_top10[0]['name']?.toString() ?? ''),
                        points: _fmtPts(_top10[0]['points']),
                        gradientColors: [const Color(0xFFE8A01A), const Color(0xFFF5C518)],
                        barColor: AppColors.yellow, barHeight: 80, badgeSize: 52,
                        crown: true, glow: true,
                      ),
                      _PodiumPlace(
                        rank: 3,
                        name: _shortName(_top10[2]['name']?.toString() ?? ''),
                        points: _fmtPts(_top10[2]['points']),
                        gradientColors: [const Color(0xFFB87333), const Color(0xFFD4915E)],
                        barColor: AppColors.bronzeBadge, barHeight: 40, badgeSize: 44,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Rangs 4 → 10
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListView.separated(
                    itemCount: (_top10.length - 3).clamp(0, 7),
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final e = _top10[i + 3];
                      return _RankRow(
                        rank: (e['rank'] as num?)?.toInt() ?? (i + 4),
                        name: e['name']?.toString() ?? '—',
                        points: _fmtPts(e['points']),
                      );
                    },
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Text(
                    'Commune et région\ndisponibles bientôt',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              ),
            // Carte épingлée — position de l'utilisateur courant
            if (_me != null)
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 44),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.05)]),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${_me!['rank'] ?? '?'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE11D28), Color(0xFFB3141E)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          AuthSession.instance.user.value?.initials ?? '?',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${AuthSession.instance.user.value?.name ?? 'Moi'} (moi)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    Text(_fmtPts(_me!['points']),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
              )
            else
              const SizedBox(height: 44),
          ],
        ),
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int rank;
  final String name;
  final String points;
  final List<Color> gradientColors;
  final Color barColor;
  final double barHeight;
  final double badgeSize;
  final bool crown;
  final bool glow;

  const _PodiumPlace({
    required this.rank, required this.name, required this.points,
    required this.gradientColors,
    required this.barColor, required this.barHeight, required this.badgeSize,
    this.crown = false, this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (crown) const Icon(Icons.emoji_events_rounded, size: 20, color: AppColors.yellow),
          Container(
            width: badgeSize, height: badgeSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(badgeSize * 0.27),
              boxShadow: glow ? [BoxShadow(color: barColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))] : null,
            ),
            child: Center(child: Icon(Icons.person_rounded, size: badgeSize * 0.5, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Text(name, textAlign: TextAlign.center,
            style: TextStyle(fontSize: glow ? 13 : 12, fontWeight: FontWeight.w700, color: glow ? barColor : AppColors.textPrimary)),
          Text(points, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            height: barHeight, width: double.infinity,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: glow ? 0.12 : 0.15),
              border: glow ? Border.all(color: barColor.withValues(alpha: 0.2)) : null,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            child: Center(
              child: Text('$rank',
                style: TextStyle(fontSize: glow ? 24 : 20, fontWeight: FontWeight.w800, color: barColor)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String points;

  const _RankRow({required this.rank, required this.name, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$rank', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          Text(points, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
