import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../parsers/parsers.dart';

class SubscriptionService {
  final http.Client _client;
  final Duration timeout;
  
  SubscriptionService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();
  
  Future<ParsedSubscription> fetchAndParse(
    String url, {
    Map<String, String>? headers,
    bool decodeBase64 = true,
  }) async {
    // 1. 获取订阅内容
    final content = await _download(url, headers);
    
    // 2. Base64 解码（如果需要）
    final decodedContent = decodeBase64 && FormatDetector.isBase64Encoded(content)
        ? FormatDetector.decodeBase64IfNeeded(content)
        : content;
    
    // 3. 解析
    return ParserFactory.parse(decodedContent);
  }
  
  Future<String> _download(
    String url,
    Map<String, String>? additionalHeaders,
  ) async {
    final uri = Uri.parse(url);
    
    final headers = {
      'User-Agent': 'SubscriptionParser/1.0',
      ...?additionalHeaders,
    };
    
    final response = await _client
        .get(uri, headers: headers)
        .timeout(timeout);
    
    if (response.statusCode != 200) {
      throw SubscriptionException(
        'Failed to download subscription: ${response.statusCode}',
        url: url,
        statusCode: response.statusCode,
      );
    }
    
    return response.body;
  }
  
  Future<SubscriptionInfo?> fetchSubscriptionInfo(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse(url);
      
      final response = await _client
          .get(uri, headers: {
            'User-Agent': 'SubscriptionParser/1.0',
            ...?headers,
          })
          .timeout(timeout);
      
      if (response.statusCode != 200) return null;
      
      // 从响应头解析订阅信息
      final subscriptionInfo = response.headers['subscription-userinfo'];
      if (subscriptionInfo != null) {
        return _parseSubscriptionInfoHeader(subscriptionInfo);
      }
      
      // 从内容中解析
      final content = response.body;
      final decodedContent = FormatDetector.isBase64Encoded(content)
          ? FormatDetector.decodeBase64IfNeeded(content)
          : content;
      
      return _extractSubscriptionInfoFromContent(decodedContent);
    } catch (_) {
      return null;
    }
  }
  
  SubscriptionInfo? _parseSubscriptionInfoHeader(String header) {
    try {
      final values = header.split(';');
      final map = <String, int>{};
      
      for (final v in values) {
        final parts = v.split('=');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = int.tryParse(parts[1].trim());
          if (value != null) {
            map[key] = value;
          }
        }
      }
      
      if (map.containsKey('upload') && 
          map.containsKey('download') && 
          map.containsKey('total') && 
          map.containsKey('expire')) {
        return SubscriptionInfo(
          upload: map['upload']!,
          download: map['download']!,
          total: map['total']!,
          expire: DateTime.fromMillisecondsSinceEpoch(
            map['expire']! * 1000,
          ),
        );
      }
    } catch (_) {}
    
    return null;
  }
  
  SubscriptionInfo? _extractSubscriptionInfoFromContent(String content) {
    // 从内容头部注释中解析订阅信息
    final lines = content.split('\n');
    
    for (final line in lines.take(10)) {
      if (line.startsWith('#') || line.startsWith('//')) {
        final index = line.indexOf(':');
        if (index == -1) continue;
        
        final key = line.substring(line.startsWith('#') ? 1 : 2, index).trim().toLowerCase();
        if (key == 'subscription-userinfo') {
          return _parseSubscriptionInfoHeader(
            line.substring(index + 1).trim(),
          );
        }
      }
    }
    
    return null;
  }
  
  void dispose() {
    _client.close();
  }
}

class SubscriptionException implements Exception {
  final String message;
  final String? url;
  final int? statusCode;
  final dynamic originalError;
  
  SubscriptionException(
    this.message, {
    this.url,
    this.statusCode,
    this.originalError,
  });
  
  @override
  String toString() => 'SubscriptionException: $message';
}
