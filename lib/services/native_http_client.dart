import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Raw result from OkHttp on the Android side.
class NativeHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const NativeHttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  dynamic get json {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'NativeHttpResponse($statusCode)';
}

class NativeHttpException implements Exception {
  final String code;
  final String message;
  const NativeHttpException(this.code, this.message);

  @override
  String toString() => 'NativeHttpException[$code]: $message';
}

/// Thin wrapper around the "com.example.parent_payment_app/http" MethodChannel.
/// Uses OkHttp on Android — completely bypasses Dart's DNS resolver.
class NativeHttpClient {
  static const _channel = MethodChannel('com.example.parent_payment_app/http');

  static Future<NativeHttpResponse> _send(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    debugPrint('[NativeHttp] $method $url');
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        method,
        {
          'url': url,
          if (headers != null) 'headers': headers,
          if (body != null) 'body': jsonEncode(body),
        },
      );

      if (result == null) {
        throw const NativeHttpException('NULL_RESULT', 'Platform returned null');
      }

      return NativeHttpResponse(
        statusCode: result['statusCode'] as int,
        body: result['body'] as String,
        headers: Map<String, String>.from(
          (result['headers'] as Map?) ?? {},
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[NativeHttp] PlatformException: ${e.code} — ${e.message}');
      throw NativeHttpException(e.code, e.message ?? 'Unknown error');
    }
  }

  static Future<NativeHttpResponse> get(
    String url, {
    Map<String, String>? headers,
  }) =>
      _send('GET', url, headers: headers);

  static Future<NativeHttpResponse> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send('POST', url, headers: headers, body: body);

  static Future<NativeHttpResponse> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send('PUT', url, headers: headers, body: body);

  static Future<NativeHttpResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) =>
      _send('DELETE', url, headers: headers);
}