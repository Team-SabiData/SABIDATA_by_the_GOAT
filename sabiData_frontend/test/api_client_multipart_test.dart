import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabidata_app/data/api/api_client.dart';

void main() {
  test('postMultipart envoie un MultipartRequest avec champs + fichier', () async {
    late http.BaseRequest captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode({'clipId': 'c1', 'status': 'peer_review'}), 201);
    });
    final client = ApiClient(mock);
    final res = await client.postMultipart(
      '/api/clips',
      {'rarity': '1', 'durationS': '4'},
      filePath: _tempAudioFile(),
    );
    expect(res['clipId'], 'c1');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/clips');
  });

  test('getBytes renvoie les octets bruts', () async {
    final mock = MockClient((req) async {
      return http.Response.bytes([9, 8, 7], 200);
    });
    final client = ApiClient(mock);
    final bytes = await client.getBytes('/api/clips/c1/audio');
    expect(bytes, [9, 8, 7]);
  });
}

String _tempAudioFile() {
  // crée un petit fichier temporaire
  final f = File('${Directory.systemTemp.path}/sabi_test.m4a')..writeAsBytesSync([1, 2, 3]);
  return f.path;
}
