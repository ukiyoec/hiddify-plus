import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class V2RayParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.v2ray;
  
  @override
  bool canParse(String content) {
    try {
      final json = jsonDecode(content);
      if (json is Map<String, dynamic>) {
        // V2Ray JSON 格式检测
        if (json.containsKey('v') || 
            json.containsKey('ps') ||
            json.containsKey('add')) {
          return true;
        }
        // v2rayN 格式
        if (json.containsKey('log') || 
            json.containsKey('inbounds') ||
            json.containsKey('outbounds')) {
          return false; // 这是 singbox 格式
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid V2Ray format');
    }
    
    final List<ProxyNode> nodes = [];
    final trimmed = content.trim();
    
    // 如果是多个 JSON 对象（每行一个），逐行解析
    final lines = trimmed.split('\n');
    for (final line in lines) {
      final json = jsonDecode(line.trim());
      if (json is Map<String, dynamic>) {
        final node = _parseV2RayNode(json);
        if (node != null) {
          nodes.add(node);
        }
      }
    }
    
    return ParsedSubscription(
      nodes: nodes,
      format: SubscriptionFormat.v2ray,
    );
  }
  
  ProxyNode? _parseV2RayNode(Map<String, dynamic> json) {
    // 单一节点格式 (v2rayN 等)
    if (json.containsKey('v') && json.containsKey('add')) {
      return _parseV2RayN(json);
    }
    
    return null;
  }
  
  ProxyNode _parseV2RayN(Map<String, dynamic> json) {
    final remark = json['ps']?.toString() ?? 'V2Ray';
    final server = json['add']?.toString() ?? '';
    final port = int.tryParse(json['port']?.toString() ?? '') ?? 0;
    final userId = json['id']?.toString();
    final alterId = int.tryParse(json['aid']?.toString() ?? '') ?? 0;
    final net = json['net']?.toString() ?? 'tcp';
    final type = json['type']?.toString() ?? 'none';
    final host = json['host']?.toString();
    final path = json['path']?.toString();
    final tls = json['tls']?.toString();
    
    return ProxyNode(
      id: _uuid.v4(),
      remark: remark,
      type: ProxyType.vmess,
      server: server,
      port: port,
      userId: userId ?? '',
      alterId: alterId,
      network: net,
      host: host,
      path: path,
      tlsSecure: tls == 'tls',
    );
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.v2ray}) {
    final buffer = StringBuffer();
    
    for (final node in nodes) {
      final json = _nodeToV2RayN(node);
      buffer.writeln(jsonEncode(json));
    }
    
    return buffer.toString();
  }
  
  Map<String, dynamic> _nodeToV2RayN(ProxyNode node) {
    return {
      'v': '2',
      'ps': node.remark,
      'add': node.server,
      'port': node.port.toString(),
      'id': node.userId ?? '',
      'aid': (node.alterId ?? 0).toString(),
      'net': node.network ?? 'tcp',
      'type': node.host ?? 'none',
      'host': node.host ?? '',
      'path': node.path ?? '',
      'tls': node.tlsSecure ? 'tls' : '',
    };
  }
}
