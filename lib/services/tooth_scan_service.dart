import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ToothScanService {
  final http.Client _client;

  ToothScanService({http.Client? client}) : _client = client ?? http.Client();

  Future<ToothScanResult?> scanNv21Frame({
    required String endpoint,
    required Uint8List bytes,
    required int width,
    required int height,
    required int rotation,
    required bool isFrontCamera,
    double? toothBboxX,
    double? toothBboxY,
    double? toothBboxW,
    double? toothBboxH,
    double? lipLeftX,
    double? lipRightX,
    double? upperLipTopY,
    double? lowerLipBottomY,
  }) async {
    final baseUrl = endpoint.trim();
    if (baseUrl.isEmpty) return null;

    final uri = Uri.parse('$baseUrl/scan/teeth');
    final body = <String, dynamic>{
      'encoding': 'nv21',
      'imageWidth': width,
      'imageHeight': height,
      'rotation': rotation,
      'isFrontCamera': isFrontCamera,
      'bytesBase64': base64Encode(bytes),
      'toothBboxX': toothBboxX,
      'toothBboxY': toothBboxY,
      'toothBboxW': toothBboxW,
      'toothBboxH': toothBboxH,
      'lipLeftX': lipLeftX,
      'lipRightX': lipRightX,
      'upperLipTopY': upperLipTopY,
      'lowerLipBottomY': lowerLipBottomY,
    }..removeWhere((key, value) => value == null);

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Tooth scan failed (${response.statusCode})');
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid tooth scan response');
    }

    return ToothScanResult.fromMap(raw);
  }

  void close() {
    _client.close();
  }
}
