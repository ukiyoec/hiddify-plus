import 'dart:convert';
import 'package:hiddify/kernel_updater/kernel_version_info.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:hiddify/subscription_parser/parsers/parsers.dart';

export 'package:hiddify/kernel_updater/kernel_version_info.dart' show KernelType;

class SubscriptionConverter {
  static final SubscriptionConverter _instance = SubscriptionConverter._internal();
  factory SubscriptionConverter() => _instance;
  SubscriptionConverter._internal();

  SubscriptionFormat detectInputFormat(String content) {
    return FormatDetector.detect(content);
  }

  String convert(
    String content, {
    required SubscriptionFormat targetFormat,
    bool decodeBase64 = true,
  }) {
    final decodedContent = decodeBase64 && FormatDetector.isBase64Encoded(content)
        ? FormatDetector.decodeBase64IfNeeded(content)
        : content;

    final sourceFormat = detectInputFormat(decodedContent);
    final parsed = ParserFactory.parse(decodedContent);

    return ParserFactory.generate(parsed.nodes, targetFormat: targetFormat);
  }

  String convertToKernel(
    String content, {
    required KernelType targetKernel,
    bool decodeBase64 = true,
  }) {
    final targetFormat = _kernelTypeToSubscriptionFormat(targetKernel);
    return convert(content, targetFormat: targetFormat, decodeBase64: decodeBase64);
  }

  List<ProxyNode> parseOnly(String content, {bool decodeBase64 = true}) {
    final decodedContent = decodeBase64 && FormatDetector.isBase64Encoded(content)
        ? FormatDetector.decodeBase64IfNeeded(content)
        : content;

    final parsed = ParserFactory.parse(decodedContent);
    return parsed.nodes;
  }

  SubscriptionFormat? detectAndConvertToClash(
    String content, {
    bool decodeBase64 = true,
  }) {
    try {
      convert(
        content,
        targetFormat: SubscriptionFormat.clash,
        decodeBase64: decodeBase64,
      );
      return SubscriptionFormat.clash;
    } catch (_) {
      return null;
    }
  }

  String nodesToFormat(
    List<ProxyNode> nodes, {
    required SubscriptionFormat targetFormat,
  }) {
    return ParserFactory.generate(nodes, targetFormat: targetFormat);
  }

  String nodesToKernel(
    List<ProxyNode> nodes, {
    required KernelType targetKernel,
    List<ProxyGroup>? groups,
  }) {
    return _generateKernelConfig(nodes, targetKernel, groups);
  }

  List<ProxyNode> mergeSubscriptions(
    List<String> contents, {
    bool decodeBase64 = true,
  }) {
    final Set<String> uniqueIds = {};
    final List<ProxyNode> mergedNodes = [];

    for (final content in contents) {
      final decodedContent = decodeBase64 && FormatDetector.isBase64Encoded(content)
          ? FormatDetector.decodeBase64IfNeeded(content)
          : content;

      try {
        final parsed = ParserFactory.parse(decodedContent);

        for (final node in parsed.nodes) {
          final key = '${node.server}:${node.port}';
          if (!uniqueIds.contains(key)) {
            uniqueIds.add(key);
            mergedNodes.add(node);
          }
        }
      } catch (_) {
        // Skip invalid subscriptions
      }
    }

    return mergedNodes;
  }

  Map<String, List<ProxyNode>> splitByProtocol(
    List<ProxyNode> nodes,
  ) {
    final Map<String, List<ProxyNode>> result = {};

    for (final node in nodes) {
      final key = node.type.key;
      result.putIfAbsent(key, () => []).add(node);
    }

    return result;
  }

  List<ProxyNode> filterByProtocol(
    List<ProxyNode> nodes,
    Set<ProxyType> allowedTypes,
  ) {
    return nodes.where((node) => allowedTypes.contains(node.type)).toList();
  }

  List<ProxyNode> filterByName(
    List<ProxyNode> nodes,
    String keyword,
  ) {
    final lowerKeyword = keyword.toLowerCase();
    return nodes.where((node) {
      return node.remark.toLowerCase().contains(lowerKeyword) ||
             node.server.toLowerCase().contains(lowerKeyword);
    }).toList();
  }

  List<ProxyGroup> generateDefaultGroups(List<ProxyNode> nodes) {
    if (nodes.isEmpty) return [];

    final proxyNames = nodes.map((n) => n.remark).toList();

    return [
      const ProxyGroup(
        name: 'auto',
        type: GroupType.urlTest,
        proxies: ['DIRECT'],
        url: 'https://www.gstatic.com/generate_204',
        interval: 300,
        tolerance: 150,
        lazy: true,
        disableUdp: false,
      ),
      ProxyGroup(
        name: 'proxy',
        type: GroupType.select,
        proxies: ['DIRECT', ...proxyNames],
      ),
      ProxyGroup(
        name: 'fallback',
        type: GroupType.fallback,
        proxies: ['proxy', 'auto'],
        url: 'https://www.gstatic.com/generate_204',
        interval: 300,
        tolerance: 150,
        lazy: true,
      ),
    ];
  }

  SubscriptionFormat _kernelTypeToSubscriptionFormat(KernelType type) {
    return switch (type) {
      KernelType.singBox => SubscriptionFormat.singbox,
      KernelType.clashMeta => SubscriptionFormat.clashMeta,
      KernelType.v2ray => SubscriptionFormat.v2ray,
    };
  }

  String _generateKernelConfig(
    List<ProxyNode> nodes,
    KernelType targetKernel,
    List<ProxyGroup>? groups,
  ) {
    final effectiveGroups = groups ?? generateDefaultGroups(nodes);

    return switch (targetKernel) {
      KernelType.singBox => _generateSingBoxConfig(nodes, effectiveGroups),
      KernelType.clashMeta => _generateClashMetaConfig(nodes, effectiveGroups),
      KernelType.v2ray => _generateV2RayConfig(nodes),
    };
  }

  String _generateSingBoxConfig(List<ProxyNode> nodes, List<ProxyGroup> groups) {
    final config = {
      'log': {'level': 'info', 'timestamp': true},
      'dns': _generateDns(),
      'inbounds': _generateDefaultInbounds(),
      'outbounds': _generateOutbounds(nodes, groups),
      'route': _generateDefaultRoute(),
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  String _generateClashMetaConfig(List<ProxyNode> nodes, List<ProxyGroup> groups) {
    final buffer = StringBuffer();

    buffer.writeln('mixed-port: 7890');
    buffer.writeln('allow-lan: false');
    buffer.writeln('mode: rule');
    buffer.writeln('log-level: info');
    buffer.writeln('external-controller: 127.0.0.1:9090');
    buffer.writeln();
    buffer.writeln('proxies:');
    for (final node in nodes) {
      buffer.writeln('  - name: "${node.remark}"');
      buffer.writeln('    type: ${_proxyTypeToClashType(node)}');
      buffer.writeln('    server: ${node.server}');
      buffer.writeln('    port: ${node.port}');
      _writeClashProxyDetails(buffer, node);
    }
    buffer.writeln();
    buffer.writeln('proxy-groups:');
    for (final group in groups) {
      buffer.writeln('  - name: "${group.name}"');
      buffer.writeln('    type: ${group.type.key}');
      buffer.writeln('    proxies:');
      for (final proxy in group.proxies) {
        buffer.writeln('      - $proxy');
      }
    }
    buffer.writeln();
    buffer.writeln('rules:');
    buffer.writeln('  - GEOIP,CN,DIRECT');
    buffer.writeln('  - MATCH,auto');

    return buffer.toString();
  }

  String _proxyTypeToClashType(ProxyNode node) {
    return switch (node.type) {
      ProxyType.vmess => 'vmess',
      ProxyType.vless => 'vless',
      ProxyType.trojan => 'trojan',
      ProxyType.trojanGo => 'trojan',
      ProxyType.ss => 'ss',
      ProxyType.ssr => 'ssr',
      ProxyType.socks5 => 'socks5',
      ProxyType.http => 'http',
      _ => 'direct',
    };
  }

  void _writeClashProxyDetails(StringBuffer buffer, ProxyNode node) {
    switch (node.type) {
      case ProxyType.vmess:
        if (node.userId != null) buffer.writeln('    uuid: ${node.userId}');
        if (node.alterId != null) buffer.writeln('    alterId: ${node.alterId}');
        if (node.encryptMethod != null) buffer.writeln('    cipher: ${node.encryptMethod}');
        break;
      case ProxyType.vless:
        if (node.userId != null) buffer.writeln('    uuid: ${node.userId}');
        break;
      case ProxyType.trojan:
      case ProxyType.trojanGo:
        if (node.password != null) buffer.writeln('    password: ${node.password}');
        break;
      case ProxyType.ss:
        if (node.encryptMethod != null) buffer.writeln('    cipher: ${node.encryptMethod}');
        if (node.password != null) buffer.writeln('    password: ${node.password}');
        break;
      case ProxyType.socks5:
      case ProxyType.http:
        if (node.username != null) buffer.writeln('    username: ${node.username}');
        if (node.password != null) buffer.writeln('    password: ${node.password}');
        break;
      default:
        break;
    }

    if (node.tlsSecure) buffer.writeln('    tls: true');
    if (node.sni != null) buffer.writeln('    servername: ${node.sni}');
  }

  String _generateV2RayConfig(List<ProxyNode> nodes) {
    final config = {
      'log': {'loglevel': 'warning'},
      'dns': _generateDns(),
      'stats': {},
      'policy': {
        'levels': {
          '0': {
            'statsUserUplink': true,
            'statsUserDownlink': true,
          },
        },
        'system': {
          'statsInboundUplink': true,
          'statsInboundDownlink': true,
        },
      },
      'inbounds': _generateV2RayInbounds(),
      'outbounds': _generateV2RayOutbounds(nodes),
      'routing': _generateV2RayRouting(),
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  Map<String, dynamic> _generateDns() {
    return {
      'servers': [
        {'address': 'tls://8.8.8.8', 'port': 443},
        {'address': 'tls://1.1.1.1', 'port': 443},
        '8.8.8.8',
        '1.1.1.1',
      ],
    };
  }

  List<Map<String, dynamic>> _generateDefaultInbounds() {
    return [
      {
        'tag': 'tun',
        'type': 'tun',
        'mtu': 9000,
        'inet4_address': '172.19.0.1/30',
        'inet6_address': 'fdfe:dcba:9876::1/126',
        'auto_route': true,
        'strict_route': true,
      },
      {
        'tag': 'mixed',
        'type': 'mixed',
        'listen': '127.0.0.1',
        'listen_port': 7890,
      },
    ];
  }

  List<Map<String, dynamic>> _generateOutbounds(List<ProxyNode> nodes, List<ProxyGroup> groups) {
    final outbounds = <Map<String, dynamic>>[];

    for (final node in nodes) {
      outbounds.add(_proxyNodeToSingBoxOutbound(node));
    }

    for (final group in groups) {
      outbounds.add({
        'tag': group.name,
        'protocol': 'selector',
        'settings': {'outbounds': group.proxies},
      });
    }

    if (outbounds.isEmpty) {
      outbounds.add({'tag': 'direct', 'protocol': 'freedom', 'settings': {}});
    }

    outbounds.add({'tag': 'dns-outbound', 'protocol': 'dns', 'settings': {}});

    return outbounds;
  }

  Map<String, dynamic> _proxyNodeToSingBoxOutbound(ProxyNode node) {
    final outbound = <String, dynamic>{
      'tag': node.remark,
      'type': _proxyTypeToSingBoxType(node.type),
      'server': node.server,
      'server_port': node.port,
    };

    switch (node.type) {
      case ProxyType.vmess:
        outbound['uuid'] = node.userId ?? '';
        outbound['alterId'] = node.alterId ?? 0;
        outbound['security'] = node.encryptMethod ?? 'auto';
        break;
      case ProxyType.vless:
        outbound['uuid'] = node.userId ?? '';
        break;
      case ProxyType.trojan:
      case ProxyType.trojanGo:
        outbound['password'] = node.password ?? '';
        break;
      case ProxyType.ss:
        outbound['method'] = node.encryptMethod ?? 'chacha20-ietf-poly1305';
        outbound['password'] = node.password ?? '';
        break;
      case ProxyType.socks5:
        outbound['username'] = node.username ?? '';
        outbound['password'] = node.password ?? '';
        break;
      default:
        break;
    }

    // Add TLS if needed
    if (node.tlsSecure) {
      outbound['tls'] = {
        'enabled': true,
        'server_name': node.sni ?? node.server,
        'insecure': false,
      };
    }

    return outbound;
  }

  Map<String, dynamic> _proxyNodeToV2RayOutbound(ProxyNode node) {
    final outbound = <String, dynamic>{
      'tag': node.remark,
      'protocol': _proxyTypeToV2RayProtocol(node.type),
    };

    switch (node.type) {
      case ProxyType.vmess:
        outbound['settings'] = {
          'vnext': [
            {
              'address': node.server,
              'port': node.port,
              'users': [
                {
                  'id': node.userId ?? '',
                  'alterId': node.alterId ?? 0,
                  'security': node.encryptMethod ?? 'auto',
                },
              ],
            },
          ],
        };
        break;
      case ProxyType.vless:
        outbound['settings'] = {
          'vnext': [
            {
              'address': node.server,
              'port': node.port,
              'users': [{'id': node.userId ?? '', 'encryption': 'none'}],
            },
          ],
        };
        break;
      case ProxyType.trojan:
      case ProxyType.trojanGo:
        outbound['settings'] = {
          'servers': [
            {'address': node.server, 'port': node.port, 'password': node.password ?? ''},
          ],
        };
        break;
      case ProxyType.ss:
        outbound['settings'] = {
          'servers': [
            {
              'address': node.server,
              'port': node.port,
              'method': node.encryptMethod ?? 'chacha20-ietf-poly1305',
              'password': node.password ?? '',
            },
          ],
        };
        break;
      default:
        outbound['settings'] = {};
    }

    return outbound;
  }

  String _proxyTypeToV2RayProtocol(ProxyType type) {
    return switch (type) {
      ProxyType.vmess => 'vmess',
      ProxyType.vless => 'vless',
      ProxyType.trojan => 'trojan',
      ProxyType.trojanGo => 'trojan',
      ProxyType.ss => 'shadowsocks',
      ProxyType.socks5 => 'socks5',
      ProxyType.http => 'http',
      _ => 'freedom',
    };
  }

  String _proxyTypeToSingBoxType(ProxyType type) {
    return switch (type) {
      ProxyType.vmess => 'vmess',
      ProxyType.vless => 'vless',
      ProxyType.trojan => 'trojan',
      ProxyType.trojanGo => 'trojan',
      ProxyType.ss => 'shadowsocks',
      ProxyType.socks5 => 'socks5',
      ProxyType.http => 'http',
      ProxyType.wireguard => 'wireguard',
      ProxyType.hysteria => 'hysteria',
      ProxyType.hysteria2 => 'hysteria2',
      ProxyType.tuic => 'tuic',
      _ => 'direct',
    };
  }

  Map<String, dynamic> _generateDefaultRoute() {
    return {
      'rules': [
        {'geosite': 'category-ads-all', 'outbound_tag': 'block'},
        {'geosite': 'cn', 'outbound_tag': 'direct'},
        {'geoip': 'private', 'outbound_tag': 'direct'},
      ],
      'auto_detect_interface': true,
    };
  }

  List<Map<String, dynamic>> _generateV2RayInbounds() {
    return [
      {
        'tag': 'socks-inbound',
        'protocol': 'socks',
        'port': 1080,
        'listen': '127.0.0.1',
        'settings': {'auth': 'noauth', 'udp': true},
      },
      {
        'tag': 'http-inbound',
        'protocol': 'http',
        'port': 10808,
        'listen': '127.0.0.1',
      },
    ];
  }

  List<Map<String, dynamic>> _generateV2RayOutbounds(List<ProxyNode> nodes) {
    final outbounds = <Map<String, dynamic>>[];

    for (final node in nodes) {
      outbounds.add(_proxyNodeToV2RayOutbound(node));
    }

    if (outbounds.isEmpty) {
      outbounds.add({'tag': 'direct', 'protocol': 'freedom', 'settings': {}});
    }

    outbounds.add({'tag': 'dns-outbound', 'protocol': 'dns', 'settings': {}});

    return outbounds;
  }

  Map<String, dynamic> _generateV2RayRouting() {
    return {
      'domainStrategy': 'IPIfNonMatch',
      'rules': [
        {'type': 'field', 'ip': ['geoip:cn', 'geoip:private'], 'outboundTag': 'direct'},
        {'type': 'field', 'domain': ['geosite:cn'], 'outboundTag': 'direct'},
      ],
    };
  }
}
