import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../models/models.dart';

class FormatDetector {
  static SubscriptionFormat detect(String content) {
    final trimmed = content.trim();
    
    // 1. 尝试 URI 解析
    if (_isUriFormat(trimmed)) {
      return _detectUriFormat(trimmed);
    }
    
    // 2. 尝试 JSON 解析
    final jsonFormat = _detectJsonFormat(trimmed);
    if (jsonFormat != null) {
      return jsonFormat;
    }
    
    // 3. 尝试 YAML 解析
    final yamlFormat = _detectYamlFormat(trimmed);
    if (yamlFormat != null) {
      return yamlFormat;
    }
    
    return SubscriptionFormat.unknown;
  }
  
  static bool _isUriFormat(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return false;
    
    final firstLine = lines.first.trim();
    return firstLine.startsWith('vmess://') ||
           firstLine.startsWith('vless://') ||
           firstLine.startsWith('trojan://') ||
           firstLine.startsWith('ss://') ||
           firstLine.startsWith('ssconf://') ||
           firstLine.startsWith('trojan-go://') ||
           firstLine.startsWith('tuic://') ||
           firstLine.startsWith('hysteria://') ||
           firstLine.startsWith('hy2://') ||
           firstLine.startsWith('ssh://') ||
           firstLine.startsWith('wg://') ||
           firstLine.startsWith('awg://') ||
           firstLine.startsWith('shadowtls://') ||
           firstLine.startsWith('mieru://');
  }
  
  static SubscriptionFormat _detectUriFormat(String content) {
    final firstLine = content.split('\n').first.trim();
    
    if (firstLine.startsWith('vmess://')) return SubscriptionFormat.vmess;
    if (firstLine.startsWith('vless://')) return SubscriptionFormat.vless;
    if (firstLine.startsWith('trojan://') || firstLine.startsWith('trojan-go://')) {
      return SubscriptionFormat.trojan;
    }
    if (firstLine.startsWith('ss://') || firstLine.startsWith('ssconf://')) {
      return SubscriptionFormat.ss;
    }
    if (firstLine.startsWith('ssr://')) return SubscriptionFormat.ssr;
    
    // 其他 URI 格式暂时归类为 unknown
    return SubscriptionFormat.unknown;
  }
  
  static SubscriptionFormat? _detectJsonFormat(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // sing-box 格式检测
      if (json.containsKey('log') || 
          json.containsKey('inbounds') ||
          json.containsKey('outbounds')) {
        return SubscriptionFormat.singbox;
      }
      
      // V2Ray 格式检测
      if (json.containsKey('v') || 
          json.containsKey('ps') ||
          json.containsKey('add') ||
          json.containsKey('port')) {
        return SubscriptionFormat.v2ray;
      }
      
      // VMess 单一节点
      if (json['protocol'] == 'vmess') {
        return SubscriptionFormat.vmess;
      }
      
    } catch (_) {}
    
    return null;
  }
  
  static SubscriptionFormat? _detectYamlFormat(String content) {
    try {
      final yaml = loadYaml(content);
      
      if (yaml is! YamlMap) return null;
      
      // Clash 检测 - 只要有 proxies 键就认为是 Clash 格式
      if (yaml.containsKey('proxies')) {
        if (yaml.containsKey('dns') || yaml.containsKey('tun') || yaml.containsKey('inbounds') || yaml.containsKey('outbounds')) {
          // 可能是 sing-box 的 Clash 格式
          if (yaml['dns'] is YamlMap && (yaml['dns'] as YamlMap).containsKey('servers')) {
            return SubscriptionFormat.singbox;
          }
          // 同时有 inbounds/outbounds 的是 sing-box
          if (yaml.containsKey('inbounds') || yaml.containsKey('outbounds')) {
            return SubscriptionFormat.singbox;
          }
        }
        // 有 proxy-groups 的是 Clash.Meta
        if (yaml.containsKey('proxy-groups')) {
          return SubscriptionFormat.clashMeta;
        }
        return SubscriptionFormat.clash;
      }
      
      // sing-box 格式 (带 inbounds/outbounds)
      if (yaml.containsKey('inbounds') || yaml.containsKey('outbounds')) {
        return SubscriptionFormat.singbox;
      }
      
    } catch (_) {}
    
    return null;
  }
  
  static bool isBase64Encoded(String content) {
    final trimmed = content.trim();
    if (trimmed.length < 4) return false;
    
    // 检查是否是有效的 Base64
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]+=*$');
    if (!base64Regex.hasMatch(trimmed)) return false;
    
    // 尝试解码检测
    try {
      final decoded = base64Decode(trimmed);
      final decodedStr = utf8.decode(decoded, allowMalformed: true);
      
      // 解码后的内容应该是有效的 JSON/YAML 或 URI
      return decodedStr.trim().startsWith('{') ||
             decodedStr.trim().startsWith('[') ||
             decodedStr.trim().startsWith('vmess://') ||
             decodedStr.trim().startsWith('vless://') ||
             decodedStr.trim().startsWith('trojan://');
    } catch (_) {
      return false;
    }
  }
  
  static String decodeBase64IfNeeded(String content) {
    final trimmed = content.trim();
    
    if (isBase64Encoded(trimmed)) {
      try {
        final decoded = base64Decode(trimmed);
        return utf8.decode(decoded, allowMalformed: true);
      } catch (_) {
        return content;
      }
    }
    
    return content;
  }
}
