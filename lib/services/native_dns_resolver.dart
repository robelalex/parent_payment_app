import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeDnsResolver {
  static const _channel = MethodChannel('com.example.parent_payment_app/dns');

  static Future<List<String>> resolveAll(String hostname) async {
    try {
      final List<dynamic> raw = await _channel.invokeMethod(
        'resolveHost',
        {'hostname': hostname},
      );
      final addresses = raw.cast<String>();
      debugPrint('[DNS] $hostname → $addresses');
      return addresses;
    } on PlatformException catch (e) {
      throw DnsResolutionException(
        hostname: hostname,
        code: e.code,
        message: e.message ?? 'Unknown DNS error',
      );
    }
  }

  static Future<String> resolveFirst(String hostname) async {
    final addresses = await resolveAll(hostname);
    if (addresses.isEmpty) {
      throw DnsResolutionException(
        hostname: hostname,
        code: 'DNS_EMPTY',
        message: 'Resolved zero addresses for $hostname',
      );
    }
    return addresses.first;
  }
}

class DnsResolutionException implements Exception {
  final String hostname;
  final String code;
  final String message;
  const DnsResolutionException({
    required this.hostname,
    required this.code,
    required this.message,
  });
  @override
  String toString() => 'DnsResolutionException[$code]: Cannot resolve "$hostname" — $message';
}