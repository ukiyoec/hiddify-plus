import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class SingBoxParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.singbox;
  
  @override
  bool canParse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json.containsKey('inbounds') || 
             json.containsKey('outbounds') ||
             json.containsKey('log');
    } catch (_) {
      return false;
    }
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid sing-box format');
    }
    
    final json = jsonDecode(content) as Map<String, dynamic>;
    final List<ProxyNode> nodes = [];
    
    // 从 outbounds 中提取代理节点
    if (json['outbounds'] is List) {
      for (final outbound in json['outbounds'] as List) {
        if (outbound is! Map<String, dynamic>) continue;
        
        final tag = outbound['tag']?.toString();
        if (tag == null) continue;
        
        final type = outbound['type']?.toString() ?? 'unknown';
        final server = _getOutboundServer(outbound);
        final port = _getOutboundPort(outbound);
        
        if (server == null || port == null) continue;
        
        final node = _createNodeFromOutbound(
          tag: tag,
          type: type,
          outbound: outbound,
          server: server,
          port: port,
        );
        
        nodes.add(node);
      }
    }
    
    return ParsedSubscription(
      nodes: nodes,
      format: SubscriptionFormat.singbox,
    );
  }
  
  String? _getOutboundServer(Map<String, dynamic> outbound) {
    return outbound['server']?.toString();
  }
  
  int? _getOutboundPort(Map<String, dynamic> outbound) {
    final port = outbound['port'] ?? outbound['server_port'];
    if (port is int) return port;
    if (port is String) return int.tryParse(port);
    return null;
  }
  
  ProxyNode _createNodeFromOutbound({
    required String tag,
    required String type,
    required Map<String, dynamic> outbound,
    required String server,
    required int port,
  }) {
    final proxyType = ProxyType.fromString(type);
    
    return ProxyNode(
      id: _uuid.v4(),
      remark: tag,
      type: proxyType,
      server: server,
      port: port,
      username: outbound['username']?.toString(),
      password: outbound['password']?.toString(),
      // TLS
      tlsSecure: outbound['tls'] != null,
      sni: _getString(outbound, ['tls', 'sni']),
      fingerprint: _getString(outbound, ['tls', 'fingerprint']),
      alpn: _getAlpn(outbound),
      // Network
      network: _getNetwork(outbound),
      host: _getString(outbound, ['transport', 'host']),
      path: _getString(outbound, ['transport', 'path']),
      // VMess/VLESS
      userId: _getString(outbound, ['security']) == 'reality' 
          ? _getString(outbound, ['reality', 'publicKey'])
          : _getString(outbound, ['uuid']),
      alterId: _getInt(outbound, ['alterId']),
      encryptMethod: _getString(outbound, ['security']),
      // Trojan
      obfs: _getString(outbound, ['obfs']),
      obfsParam: _getString(outbound, ['obfs-password']),
    );
  }
  
  String? _getString(Map<String, dynamic> json, List<String> keys) {
    dynamic current = json;
    for (final key in keys) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current?.toString();
  }
  
  int? _getInt(Map<String, dynamic> json, List<String> keys) {
    final value = _getString(json, keys);
    return value != null ? int.tryParse(value) : null;
  }
  
  String? _getNetwork(Map<String, dynamic> outbound) {
    final transport = outbound['transport'];
    if (transport is Map<String, dynamic>) {
      return transport['type']?.toString() ?? 'tcp';
    }
    return outbound['network']?.toString();
  }
  
  String? _getAlpn(Map<String, dynamic> outbound) {
    final tls = outbound['tls'];
    if (tls is Map<String, dynamic>) {
      final alpn = tls['alpn'];
      if (alpn is List && alpn.isNotEmpty) {
        return alpn.first.toString();
      }
    }
    return null;
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.singbox}) {
    final outbounds = <Map<String, dynamic>>[];
    
    for (final node in nodes) {
      outbounds.add(_nodeToOutbound(node));
    }
    
    final json = {
      'log': {
        'level': 'info',
      },
      'inbounds': [
        {
          'type': 'mixed',
          'port': 7890,
          'listen': '127.0.0.1',
        }
      ],
      'outbounds': outbounds,
    };
    
    return const JsonEncoder.withIndent('  ').convert(json);
  }
  
  Map<String, dynamic> _nodeToOutbound(ProxyNode node) {
    final outbound = <String, dynamic>{
      'tag': node.remark,
      'type': node.type.key,
      'server': node.server,
      'port': node.port,
    };
    
    switch (node.type) {
      case ProxyType.vmess:
        outbound['uuid'] = node.userId ?? '';
        outbound['alterId'] = node.alterId ?? 0;
        outbound['security'] = node.encryptMethod ?? 'auto';
        break;
        
      case ProxyType.vless:
        outbound['uuid'] = node.userId ?? '';
        if (node.tlsSecure) {
          outbound['tls'] = {
            'enabled': true,
            'server_name': node.sni,
            'fingerprint': node.fingerprint,
          };
        }
        break;
        
      case ProxyType.trojan:
        outbound['password'] = node.password ?? '';
        if (node.tlsSecure) {
          outbound['tls'] = {
            'enabled': true,
            'server_name': node.sni,
            'fingerprint': node.fingerprint,
          };
        }
        break;
        
      case ProxyType.ss:
        outbound['method'] = node.username ?? 'aes-128-gcm';
        outbound['password'] = node.password ?? '';
        break;
        
      case ProxyType.wireguard:
        outbound['private_key'] = node.privateKey ?? '';
        outbound['peer_public_key'] = node.publicKey ?? '';
        break;
        
      default:
        break;
    }
    
    // 添加 transport
    if (node.network != null && node.network != 'tcp') {
      outbound['transport'] = {
        'type': node.network,
        if (node.host != null) 'host': node.host,
        if (node.path != null) 'path': node.path,
      };
    }
    
    return outbound;
  }
}
