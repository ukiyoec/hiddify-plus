import 'package:yaml/yaml.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class ClashParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.clash;
  
  @override
  bool canParse(String content) {
    try {
      final yaml = loadYaml(content);
      if (yaml is! YamlMap) return false;
      // 只要有 proxies 键就认为是有效的 Clash 格式
      return yaml.containsKey('proxies');
    } catch (_) {
      return false;
    }
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid Clash format');
    }
    
    final yaml = loadYaml(content) as YamlMap;
    final List<ProxyNode> nodes = [];
    final List<ProxyGroup> groups = [];
    SubscriptionInfo? info;
    
    // 解析节点
    if (yaml['proxies'] is YamlList) {
      for (final proxy in yaml['proxies'] as YamlList) {
        final node = _parseProxy(proxy as YamlMap);
        nodes.add(node);
      }
    }
    
    // 解析代理组
    if (yaml['proxy-groups'] is YamlList) {
      for (final group in yaml['proxy-groups'] as YamlList) {
        final parsedGroup = _parseGroup(group as YamlMap);
        groups.add(parsedGroup);
      }
    }
    
    return ParsedSubscription(
      nodes: nodes,
      groups: groups,
      info: info,
      format: SubscriptionFormat.clash,
    );
  }
  
  ProxyNode _parseProxy(YamlMap proxy) {
    final name = proxy['name']?.toString() ?? 'Unknown';
    final typeStr = proxy['type']?.toString() ?? 'unknown';
    final type = ProxyType.fromString(typeStr);
    final server = proxy['server']?.toString() ?? '';
    final port = _parsePort(proxy['port']);
    
    final node = ProxyNode(
      id: _uuid.v4(),
      remark: name,
      type: type,
      server: server,
      port: port,
      username: proxy['username']?.toString(),
      password: proxy['password']?.toString(),
      encryptMethod: proxy['cipher']?.toString(),
      // Network
      network: proxy['network']?.toString(),
      host: proxy['host']?.toString(),
      path: proxy['path']?.toString(),
      // TLS
      tlsSecure: proxy['tls'] == true || proxy['tls'] == 'true',
      sni: proxy['sni']?.toString(),
      fingerprint: proxy['fingerprint']?.toString(),
      alpn: proxy['alpn']?.toString(),
      // Shadowsocks specific
      obfs: proxy['obfs']?.toString(),
      obfsParam: proxy['obfs-password']?.toString(),
    );
    
    return node;
  }
  
  ProxyGroup _parseGroup(YamlMap group) {
    final name = group['name']?.toString() ?? 'Unnamed';
    final typeStr = group['type']?.toString() ?? 'select';
    final type = GroupType.fromString(typeStr);
    
    List<String> proxies = [];
    if (group['proxies'] is YamlList) {
      proxies = (group['proxies'] as YamlList)
          .map((p) => p.toString())
          .toList();
    }
    
    return ProxyGroup(
      name: name,
      type: type,
      proxies: proxies,
      url: group['url']?.toString(),
      interval: _parseInt(group['interval'] ?? 300),
      timeout: _parseInt(group['timeout'] ?? 5),
    );
  }
  
  int _parsePort(dynamic port) {
    if (port == null) return 0;
    if (port is int) return port;
    return int.tryParse(port.toString()) ?? 0;
  }
  
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.clash}) {
    final buffer = StringBuffer();
    
    buffer.writeln('# Clash配置');
    buffer.writeln('port: 7890');
    buffer.writeln('socks-port: 7891');
    buffer.writeln('mixed-port: 7892');
    buffer.writeln('allow-lan: false');
    buffer.writeln('mode: rule');
    buffer.writeln('log-level: info');
    buffer.writeln('external-controller: 127.0.0.1:9090');
    buffer.writeln();
    
    buffer.writeln('proxies:');
    for (final node in nodes) {
      buffer.writeln('  - name: "${node.remark}"');
      buffer.writeln('    type: ${node.type.key}');
      buffer.writeln('    server: ${node.server}');
      buffer.writeln('    port: ${node.port}');
      
      if (node.password != null) {
        buffer.writeln('    password: ${node.password}');
      }
      if (node.username != null) {
        buffer.writeln('    username: ${node.username}');
      }
      
      if (node.network != null) {
        buffer.writeln('    network: ${node.network}');
      }
      if (node.host != null) {
        buffer.writeln('    host: ${node.host}');
      }
      if (node.path != null) {
        buffer.writeln('    path: ${node.path}');
      }
      
      if (node.tlsSecure) {
        buffer.writeln('    tls: true');
      }
      if (node.sni != null) {
        buffer.writeln('    sni: ${node.sni}');
      }
      if (node.fingerprint != null) {
        buffer.writeln('    fingerprint: ${node.fingerprint}');
      }
      
      buffer.writeln();
    }
    
    buffer.writeln('proxy-groups:');
    buffer.writeln('  - name: Proxy');
    buffer.writeln('    type: select');
    buffer.writeln('    proxies:');
    for (final node in nodes) {
      buffer.writeln('      - ${node.remark}');
    }
    
    return buffer.toString();
  }
}

extension ClashProxyNodeExtension on ProxyNode {
  String get cipherName => encryptMethod ?? '';
}
