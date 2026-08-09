import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: query);
  }

  Never _rethrowNetwork(Object error) {
    final text = error.toString().toLowerCase();
    if (error is SocketException ||
        text.contains('socketexception') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('failed host lookup')) {
      throw ApiException(
        'Cannot reach SafeLink server. Keep USB connected and run:\n'
        'adb reverse tcp:8000 tcp:8000',
      );
    }
    throw ApiException('Network error. Please try again.');
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Invalid server response (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      (body['message'] as String?) ?? 'Request failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      _rethrowNetwork(e);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client
          .get(
            _uri(path),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      _rethrowNetwork(e);
    }
  }

  Future<bool> health() async {
    try {
      final body = await _get('/health');
      return body['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  Future<ScanResult> scanUrl(String url) async {
    final body = await _post('/scan-url', {'url': url});
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return ScanResult.fromApi(data);
  }

  Future<List<ScanRecord>> scanHistory() async {
    final body = await _get('/scan-history');
    final data = body['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => ScanRecord.fromScanApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<BreachCheckResult> checkBreach(String identifier) async {
    final body = await _post('/check-breach', {'identifier': identifier});
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return BreachCheckResult.fromApi(data);
  }

  Future<List<ScanRecord>> breachHistory() async {
    final body = await _get('/breach-history');
    final data = body['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => ScanRecord.fromBreachApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SmsAnalysisResult> analyzeSms(String message) async {
    final body = await _post('/analyze-sms', {'message': message});
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return SmsAnalysisResult.fromApi(data);
  }

  Future<String> generateTempMail() async {
    final body = await _post('/temp-mail/generate', {});
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return (data['email'] as String?) ?? '';
  }

  Future<List<TempMailMessage>> tempMailInbox(String address) async {
    final encoded = Uri.encodeComponent(address);
    final body = await _get('/temp-mail/inbox/$encoded');
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final messages = data['messages'];
    if (messages is! List) return [];
    return messages
        .whereType<Map>()
        .map((e) => TempMailMessage.fromApi(Map<String, dynamic>.from(e)))
        .toList();
  }
}
