import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/contribution_api.dart';
import '../api/api_exception.dart';

/// Un enregistrement en attente d'envoi (métadonnées + audio persisté).
class OutboxItem {
  final String id;
  final String audioPath;
  final int rarity;
  final int durationS;
  final bool commercialUse;
  final String consentVersion;
  final String? language;
  final String? dialect;
  final String? region;

  OutboxItem({
    required this.id,
    required this.audioPath,
    required this.rarity,
    required this.durationS,
    required this.commercialUse,
    required this.consentVersion,
    this.language,
    this.dialect,
    this.region,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'audioPath': audioPath, 'rarity': rarity, 'durationS': durationS,
        'commercialUse': commercialUse, 'consentVersion': consentVersion,
        'language': language, 'dialect': dialect, 'region': region,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
        id: j['id'] as String,
        audioPath: j['audioPath'] as String,
        rarity: (j['rarity'] as num).toInt(),
        durationS: (j['durationS'] as num).toInt(),
        commercialUse: j['commercialUse'] == true,
        consentVersion: j['consentVersion']?.toString() ?? 'v1',
        language: j['language']?.toString(),
        dialect: j['dialect']?.toString(),
        region: j['region']?.toString(),
      );
}

/// File d'attente locale des enregistrements : permet d'enregistrer hors-ligne
/// et de synchroniser automatiquement au retour du réseau.
class OutboxService {
  OutboxService._();
  static final OutboxService instance = OutboxService._();

  static const _kQueue = 'outbox_clips';

  /// Nombre d'enregistrements en attente (pour le badge UI).
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  bool _syncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  final _api = ContributionApi();

  /// À appeler au démarrage : compte la file, écoute le réseau, tente une sync.
  Future<void> init() async {
    await _refreshCount();
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) unawaited(sync());
    });
    unawaited(sync());
  }

  Future<List<OutboxItem>> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kQueue) ?? [];
    final items = <OutboxItem>[];
    for (final s in raw) {
      try {
        items.add(OutboxItem.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)));
      } catch (_) {/* entrée corrompue ignorée */}
    }
    return items;
  }

  Future<void> _save(List<OutboxItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kQueue, items.map((i) => jsonEncode(i.toJson())).toList());
    pendingCount.value = items.length;
  }

  Future<void> _refreshCount() async {
    pendingCount.value = (await _load()).length;
  }

  /// Copie l'audio dans un dossier persistant et met le clip en file d'attente.
  Future<void> enqueue({
    required String audioPath,
    required int rarity,
    required int durationS,
    required bool commercialUse,
    required String consentVersion,
    String? language,
    String? dialect,
    String? region,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/outbox');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = '${outDir.path}/$id.m4a';
    try {
      await File(audioPath).copy(dest);
    } catch (_) {/* copie impossible : on gardera le chemin d'origine */}
    final items = await _load();
    items.add(OutboxItem(
      id: id,
      audioPath: File(dest).existsSync() ? dest : audioPath,
      rarity: rarity,
      durationS: durationS,
      commercialUse: commercialUse,
      consentVersion: consentVersion,
      language: language,
      dialect: dialect,
      region: region,
    ));
    await _save(items);
  }

  /// Envoie les clips en file un par un. S'arrête sur erreur réseau/auth (elle
  /// réessaiera) ; retire les clips définitivement invalides (4xx hors 401).
  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      for (final item in await _load()) {
        try {
          await _api.submitClip(
            rarity: item.rarity,
            durationS: item.durationS,
            commercialUse: item.commercialUse,
            consentVersion: item.consentVersion,
            audioPath: item.audioPath,
            language: item.language,
            dialect: item.dialect,
            region: item.region,
          );
          await _remove(item);
        } on ApiException catch (e) {
          final sc = e.statusCode;
          if (sc != null && sc >= 400 && sc < 500 && sc != 401) {
            await _remove(item); // clip invalide (audio hors-limites…) → abandon
          } else {
            break; // réseau / 401 / 5xx → réessaiera plus tard
          }
        } catch (_) {
          break;
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _remove(OutboxItem item) async {
    final items = (await _load())..removeWhere((i) => i.id == item.id);
    await _save(items);
    try {
      await File(item.audioPath).delete();
    } catch (_) {}
  }
}
