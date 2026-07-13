import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/motif_header.dart';
import '../widgets/app_body.dart';
import '../widgets/progress_bar.dart';
import '../data/api/regions_api.dart';
import '../data/prefs/dialect_prefs.dart';

/// Coordonnées des régions backend dans l'espace 350×218 du painter.
/// Une région absente de cette table n'apparaît pas sur la carte (pas d'erreur).
const Map<String, Offset> _regionCoords = {
  'Ouagadougou':    Offset(174, 128),
  'Koudougou':      Offset(112, 130),
  'Ouahigouya':     Offset(118, 55),
  'Yatenga':        Offset(140, 62),
  'Bobo-Dioulasso': Offset(66, 158),
  'Dédougou':       Offset(85, 105),
  'Dori':           Offset(248, 74),
  "Fada N'Gourma":  Offset(268, 142),
};

/// Échelle de couleur commune carte + liste : jaune < 10 %, orange < 30 %.
Color _coverageColor(double pct) =>
    pct < 0.1 ? const Color(0xFFF5A624) : (pct < 0.3 ? const Color(0xFFE87D3E) : const Color(0xFF6B7E9E));

class DialectMapScreen extends StatefulWidget {
  final RegionsApi? regionsApi;

  const DialectMapScreen({super.key, this.regionsApi});

  @override
  State<DialectMapScreen> createState() => _DialectMapScreenState();
}

class _DialectMapScreenState extends State<DialectMapScreen> {
  List<Map<String, dynamic>> _coverage = [];
  bool _loadingCoverage = true;

  @override
  void initState() {
    super.initState();
    _loadCoverage();
  }

  /// Charge la couverture régionale réelle (GET /api/regions).
  /// Best-effort : la carte est une route publique mais l'endpoint peut
  /// exiger un jeton mobile (401 pour un visiteur non connecté) — on
  /// retombe alors sur une liste vide plutôt que de planter l'écran.
  Future<void> _loadCoverage() async {
    List<Map<String, dynamic>> mapped = [];
    try {
      final data = await (widget.regionsApi ?? RegionsApi()).coverage();
      mapped = data.map((r) {
        final pct = (r['coveragePct'] as num?)?.toDouble() ?? 0.0;
        final region = r['region']?.toString() ?? '—';
        final zone = r['zone']?.toString() ?? '';
        return {
          'region': region,
          'zone': zone,
          'city': zone.isNotEmpty ? '$region ($zone)' : region,
          'clips': (r['clips'] as num?)?.toInt() ?? 0,
          'pct': pct,
        };
      }).toList();
    } catch (_) {
      // Endpoint protégé ou serveur injoignable — carte vide, pas de crash.
    }
    if (mounted) {
      setState(() {
        _coverage = mapped;
        _loadingCoverage = false;
      });
    }
  }

  /// Zone la plus sous-représentée — celle qui rapporte le plus à enregistrer.
  Map<String, dynamic>? get _rarest {
    if (_coverage.isEmpty) return null;
    final sorted = [..._coverage]..sort((a, b) => (a['pct'] as double).compareTo(b['pct'] as double));
    return sorted.first;
  }

  /// Position du pin « Vous » — région du profil, si connue de la table.
  Offset? get _userPin => _regionCoords[DialectPrefs.region];

  @override
  Widget build(BuildContext context) {
    final rarest = _rarest;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBody(
        child: SingleChildScrollView(
          child: Column(
            children: [
            MotifHeader(
              motif: 'assets/motifs/motif_dialecte.png',
              title: 'Carte des dialectes',
              subtitle: 'Distribution des enregistrements par zone',
              height: 150,
              scrim: const Color(0xFF07223B),
              onBack: () => context.go('/dashboard'),
            ),
            const SizedBox(height: 16),
            // Map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(
                  size: const Size(double.infinity, 200),
                  painter: _BurkinaMapPainter(
                    points: _coverage
                        .where((c) => _regionCoords.containsKey(c['region']))
                        .map((c) => _MapPoint(
                              offset: _regionCoords[c['region']]!,
                              clips: c['clips'] as int,
                              color: _coverageColor(c['pct'] as double),
                            ))
                        .toList(),
                    userPin: _userPin,
                    userRegion: DialectPrefs.region,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 80, height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.textSecondary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rare', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        Text('Abondant', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_userPin != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    const Text('Vous', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Zone la plus sous-représentée — détail réel
            if (rarest != null) _rarestCard(rarest),
            const SizedBox(height: 12),
            // Coverage stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Couverture par zone',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.06 * 11)),
                  const SizedBox(height: 10),
                  if (_loadingCoverage)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    )
                  else if (_coverage.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Couverture indisponible.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    )
                  else
                    ..._coverage.map((c) {
                      final pct = c['pct'] as double;
                      final color = _coverageColor(pct);
                      final isStarred = pct < 0.1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(c['city'] as String,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: isStarred ? color : AppColors.textPrimary)),
                            ),
                            Expanded(
                              child: AppProgressBar(value: pct, color: color),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 38,
                              child: Text('${c['clips']}', textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, color: isStarred ? color : AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rarestCard(Map<String, dynamic> zone) {
    final pct = zone['pct'] as double;
    final urgent = pct < 0.1;
    final bonus = pct < 0.1 ? '×3 pts' : (pct < 0.3 ? '×2 pts' : '—');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.place_rounded, size: 18, color: AppColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone['region'] as String,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Text('Zone ${zone['zone']} · Burkina Faso',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${zone['clips']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const Text('clips', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: (urgent ? AppColors.red : AppColors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(urgent ? Icons.warning_amber_rounded : Icons.trending_up_rounded,
                            size: 14, color: urgent ? AppColors.red : AppColors.orange),
                          const SizedBox(width: 4),
                          Text(urgent ? 'Urgent' : 'À renforcer',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: urgent ? AppColors.red : AppColors.orange)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text('Sous-représenté', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(bonus, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 2),
                      const Text('Bonus rareté', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPoint {
  final Offset offset; // espace 350×218
  final int clips;
  final Color color;
  const _MapPoint({required this.offset, required this.clips, required this.color});
}

class _BurkinaMapPainter extends CustomPainter {
  final List<_MapPoint> points;
  final Offset? userPin;
  final String? userRegion;

  _BurkinaMapPainter({required this.points, this.userPin, this.userRegion});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF2EDE7);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(14)), bg);

    // Burkina Faso rough outline (simplified polygon)
    final scaledPath = Path();
    final sx = size.width / 350;
    final sy = size.height / 218;

    scaledPath
      ..moveTo(40 * sx, 30 * sy)
      ..lineTo(95 * sx, 14 * sy)
      ..lineTo(168 * sx, 9 * sy)
      ..lineTo(230 * sx, 20 * sy)
      ..lineTo(280 * sx, 42 * sy)
      ..lineTo(308 * sx, 78 * sy)
      ..lineTo(302 * sx, 122 * sy)
      ..lineTo(284 * sx, 158 * sy)
      ..lineTo(255 * sx, 184 * sy)
      ..lineTo(206 * sx, 206 * sy)
      ..lineTo(158 * sx, 212 * sy)
      ..lineTo(110 * sx, 203 * sy)
      ..lineTo(70 * sx, 184 * sy)
      ..lineTo(40 * sx, 156 * sy)
      ..lineTo(20 * sx, 120 * sy)
      ..lineTo(22 * sx, 74 * sy)
      ..close();

    canvas.drawPath(scaledPath, Paint()
      ..color = const Color(0xFFE6DFD5)
      ..style = PaintingStyle.fill);
    canvas.drawPath(scaledPath, Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Halos de densité — rayon et intensité ∝ clips réels (normalisés).
    final maxClips = points.fold<int>(0, (m, p) => p.clips > m ? p.clips : m);
    for (final p in points) {
      final cx = p.offset.dx * sx;
      final cy = p.offset.dy * sy;
      if (maxClips == 0 || p.clips == 0) {
        // Aucune donnée : petit point discret, la zone existe mais est vide.
        canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = p.color.withValues(alpha: 0.45));
        continue;
      }
      final ratio = p.clips / maxClips;
      final r = 14 + 40 * ratio;
      for (final (f, a) in [(1.0, 0.05), (0.6, 0.12), (0.32, 0.24)]) {
        canvas.drawCircle(Offset(cx, cy), r * f, Paint()..color = p.color.withValues(alpha: a));
      }
      canvas.drawCircle(Offset(cx, cy), 3.5 + 2.5 * ratio, Paint()..color = p.color.withValues(alpha: 0.9));
    }

    // Pin « Vous » — région du profil.
    final pin = userPin;
    if (pin != null) {
      final px = pin.dx * sx;
      final py = pin.dy * sy;
      canvas.drawCircle(Offset(px, py), 13, Paint()..color = AppColors.primary.withValues(alpha: 0.18));
      canvas.drawCircle(Offset(px, py), 7.5, Paint()..color = AppColors.primary);
      if (userRegion != null && userRegion!.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: userRegion,
            style: const TextStyle(fontSize: 7, color: AppColors.primary, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(px - tp.width / 2, py - 24));
      }
    }
  }

  @override
  bool shouldRepaint(_BurkinaMapPainter old) =>
      old.points != points || old.userPin != userPin || old.userRegion != userRegion;
}
