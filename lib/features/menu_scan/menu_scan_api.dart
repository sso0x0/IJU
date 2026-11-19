import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../app/api.dart';

/// 메뉴 카드 한 장의 데이터 (서버 /ai/menu-scan의 items 한 개).
class MenuCardData {
  const MenuCardData({
    required this.name,
    required this.confidence,
    this.meaning,
    this.romanization,
    this.description,
    this.correctedFrom,
  });

  factory MenuCardData.fromJson(Map<String, dynamic> json) => MenuCardData(
    name: json['name'] as String,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    meaning: json['meaning'] as String?,
    romanization: json['romanization'] as String?,
    description: json['description'] as String?,
    correctedFrom: json['corrected_from'] as String?,
  );

  final String name;
  final double confidence;
  final String? meaning;
  final String? romanization;
  final String? description;
  final String? correctedFrom;

  /// 손글씨·흐린 글씨라 사용자가 확인해야 하는 메뉴
  bool get needsCheck => confidence < 0.6;

  /// 메뉴판에서 읽은 그대로의 글씨 (이름 고치기 시트의 '찍은 글씨').
  String get scannedText => correctedFrom ?? name;

  /// 사용자가 이름을 고쳤을 때. 뜻·발음은 원래 메뉴 것이라 지우고,
  /// 찍은 글씨는 [correctedFrom]에 남겨 둡니다.
  MenuCardData renamed(String newName) =>
      MenuCardData(name: newName, confidence: 1, correctedFrom: scannedText);
}

class MenuScanResult {
  const MenuScanResult({
    required this.items,
    required this.rawLines,
    required this.elapsedMs,
    this.error,
  });

  factory MenuScanResult.fromJson(Map<String, dynamic> json) => MenuScanResult(
    items: [
      for (final i in json['items'] as List? ?? [])
        MenuCardData.fromJson(i as Map<String, dynamic>),
    ],
    rawLines: [for (final l in json['raw_lines'] as List? ?? []) '$l'],
    elapsedMs: json['elapsed_ms'] as int? ?? 0,
    error: json['error'] as String?,
  );

  final List<MenuCardData> items;
  final List<String> rawLines;
  final int elapsedMs;
  final String? error;
}

class MenuScanException implements Exception {
  const MenuScanException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 메뉴판 사진을 서버로 보내 메뉴 목록을 받습니다.
Future<MenuScanResult> scanMenu(
  Uint8List image, {
  required String filename,
  required String language,
  String? placeId,
}) async {
  final request =
      http.MultipartRequest('POST', Uri.parse('${Api.baseUrl}/ai/menu-scan'))
        ..fields['language'] = language
        ..files.add(
          http.MultipartFile.fromBytes('image', image, filename: filename),
        );
  if (placeId != null) request.fields['place_id'] = placeId;

  final http.Response response;
  try {
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    response = await http.Response.fromStream(streamed);
  } catch (_) {
    throw const MenuScanException('서버에 연결할 수 없어요. 서버가 켜져 있는지 확인해 주세요.');
  }
  if (response.statusCode != 200) {
    throw MenuScanException('서버 오류가 났어요 (${response.statusCode})');
  }
  final json = jsonDecode(utf8.decode(response.bodyBytes));
  return MenuScanResult.fromJson(json as Map<String, dynamic>);
}
