import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'native_dns_resolver.dart';

class ApiClient {
  static const String _hostname = 'felege-selam-payment-system.onrender.com';
  static const String _basePath = '/api';

  static String? _resolvedIp;
  static http.Client? _httpClient;

  static String? get resolvedIp => _resolvedIp;
  static bool get isInitialized => _httpClient != null;

  static Future<void> initialize() async {
    try {
      _resolvedIp = await NativeDnsResolver.resolveFirst(_hostname);
      _httpClient = _buildClient(_resolvedIp!);
      debugPrint('[ApiClient] Ready — using IP: $_resolvedIp');
    } on DnsResolutionException catch (e) {
      debugPrint('[ApiClient] Native DNS failed: $e — falling back to Dart resolver');
      _resolvedIp = null;
      _httpClient = http.Client();
    }
  }

  static http.Client _buildClient(String ip) {
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..badCertificateCallback = (cert, host, port) {
        debugPrint('[ApiClient] Bad certificate for $host:$port — rejecting');
        return false;
      };

    inner.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final targetUri = uri.replace(host: ip);
      debugPrint('[ApiClient] Connecting to $targetUri (for host: $_hostname)');
      return SecureSocket.startConnect(
        ip,
        uri.port > 0 ? uri.port : 443,
        context: SecurityContext.defaultContext,
        onBadCertificate: (cert) => false,
      );
    };

    return IOClient(inner);
  }

  static Map<String, String> _baseHeaders({Map<String, String>? extra}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Host': _hostname,
        ...?extra,
      };

  static Uri _buildUri(String endpoint) {
    return Uri.https(_hostname, '$_basePath/$endpoint');
  }

  static Future<void> _ensureInitialized() async {
    if (!isInitialized) await initialize();
  }

  static Future<ApiResponse> get(String endpoint, {Map<String, String>? queryParams, String? authToken}) async {
    await _ensureInitialized();
    final uri = _buildUri(endpoint).replace(queryParameters: queryParams);
    final headers = _baseHeaders(extra: authToken != null ? {'Authorization': 'Bearer $authToken'} : null);
    final raw = await _httpClient!.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    return ApiResponse.from(raw);
  }

  static Future<ApiResponse> post(String endpoint, Map<String, dynamic> body, {String? authToken}) async {
    await _ensureInitialized();
    final uri = _buildUri(endpoint);
    final headers = _baseHeaders(extra: authToken != null ? {'Authorization': 'Bearer $authToken'} : null);
    final raw = await _httpClient!.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    return ApiResponse.from(raw);
  }

  static Future<ApiResponse> put(String endpoint, Map<String, dynamic> body, {String? authToken}) async {
    await _ensureInitialized();
    final uri = _buildUri(endpoint);
    final headers = _baseHeaders(extra: authToken != null ? {'Authorization': 'Bearer $authToken'} : null);
    final raw = await _httpClient!.put(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    return ApiResponse.from(raw);
  }

  static Future<ApiResponse> delete(String endpoint, {String? authToken}) async {
    await _ensureInitialized();
    final uri = _buildUri(endpoint);
    final headers = _baseHeaders(extra: authToken != null ? {'Authorization': 'Bearer $authToken'} : null);
    final raw = await _httpClient!.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
    return ApiResponse.from(raw);
  }

  static Future<void> refresh() async {
    _httpClient?.close();
    _httpClient = null;
    _resolvedIp = null;
    await initialize();
  }

  static void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }
}

class ApiResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final bool isSuccess;

  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.isSuccess,
  });

  factory ApiResponse.from(http.Response r) => ApiResponse(
        statusCode: r.statusCode,
        body: r.body,
        headers: r.headers,
        isSuccess: r.statusCode >= 200 && r.statusCode < 300,
      );

  dynamic get json {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  ApiResponse validated() {
    if (!isSuccess) throw ApiResponseException(this);
    return this;
  }

  @override
  String toString() => 'ApiResponse($statusCode)';
}

class ApiResponseException implements Exception {
  final ApiResponse response;
  ApiResponseException(this.response);
  @override
  String toString() => 'ApiResponseException: HTTP ${response.statusCode} — ${response.body}';
}