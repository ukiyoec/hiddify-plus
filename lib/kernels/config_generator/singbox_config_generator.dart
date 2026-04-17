import 'dart:convert';
import 'package:hiddify/subscription_parser/models/models.dart';

class SingBoxConfigGenerator {
  static Map<String, dynamic> generateConfig({
    required List<ProxyNode> nodes,
    required List<ProxyGroup> groups,
    Map<String, dynamic>? inboundOptions,
    Map<String, dynamic>? routingOptions,
  }) {
    return {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': _generateDns(),
      'inbounds': inboundOptions ?? _generateDefaultInbounds(),
      'outbounds': _generateOutbounds(nodes, groups),
      'route': routingOptions ?? _generateDefaultRoute(),
    };
  }

  static Map<String, dynamic> _generateDns() {
    return {
      'servers': [
        {'tag': 'google', 'address': 'tls://8.8.8.8'},
        {'tag': 'cloudflare', 'address': 'tls://1.1.1.1'},
        {'tag': 'quad9', 'address': 'tls://9.9.9.9'},
      ],
    };
  }

  static List<Map<String, dynamic>> _generateDefaultInbounds() {
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

  static List<Map<String, dynamic>> _generateOutbounds(
    List<ProxyNode> nodes,
    List<ProxyGroup> groups,
  ) {
    final outbounds = <Map<String, dynamic>>[];

    for (final node in nodes) {
      outbounds.add(_proxyNodeToOutbound(node));
    }

    for (final group in groups) {
      outbounds.add(_proxyGroupToOutbound(group, nodes));
    }

    if (outbounds.isEmpty) {
      outbounds.add({'tag': 'direct', 'type': 'direct'});
    }

    outbounds.add({'tag': 'dns-out', 'type': 'dns'});

    return outbounds;
  }

  static Map<String, dynamic> _proxyNodeToOutbound(ProxyNode node) {
    final outbound = <String, dynamic>{
      'tag': node.remark,
      'type': _proxyTypeToSingBoxType(node.type),
    };

    switch (node.type) {
      case ProxyType.vmess:
        outbound['settings'] = {
          'address': node.server,
          'port': node.port,
          'uuid': node.userId ?? '',
          'alterId': node.alterId ?? 0,
          'security': node.encryptMethod ?? 'auto',
        };
        if (node.network != null) {
          outbound['network'] = node.network;
        }
        break;

      case ProxyType.vless:
        outbound['settings'] = {
          'address': node.server,
          'port': node.port,
          'uuid': node.userId ?? '',
          'flow': node.transport == 'grpc' ? 'xtls-rprx-vision' : '',
        };
        if (node.tlsSecure) {
          outbound['tls'] = _generateTlsSettings(node);
        }
        break;

      case ProxyType.trojan:
        outbound['settings'] = {
          'address': node.server,
          'port': node.port,
          'password': node.password ?? '',
        };
        if (node.tlsSecure) {
          outbound['tls'] = _generateTlsSettings(node);
        }
        break;

      case ProxyType.ss:
        outbound['settings'] = {
          'address': node.server,
          'port': node.port,
          'method': node.encryptMethod ?? 'chacha20-poly1305',
          'password': node.password ?? '',
        };
        break;

      case ProxyType.ssr:
        outbound['settings'] = {
          'address': node.server,
          'port': node.port,
          'method': node.encryptMethod ?? 'chacha20-ietf',
          'password': node.password ?? '',
          'obfs': node.obfs ?? 'plain',
          'obfs_param': node.obfsParam ?? '',
          'protocol': node.protocolParam ?? 'origin',
          'protocol_param': '',
        };
        break;

      default:
        outbound['settings'] = {
          'address': node.server,
          'port': node.port,
        };
    }

    if (node.network != null && node.type != ProxyType.vmess) {
      outbound['network'] = node.network;
    }

    if (node.transport != null && node.type == ProxyType.vmess) {
      outbound['transport'] = _generateTransport(node.transport!, node);
    } else if (node.network == 'ws' || node.network == 'grpc') {
      outbound['transport'] = _generateTransport(node.network!, node);
    }

    return outbound;
  }

  static Map<String, dynamic> _proxyGroupToOutbound(
    ProxyGroup group,
    List<ProxyNode> nodes,
  ) {
    final typeStr = group.type.key;

    return {
      'tag': group.name,
      'type': typeStr == 'urlTest' ? 'urltest' : typeStr,
      if (typeStr == 'urlTest' || typeStr == 'fallback')
        'url': group.url ?? 'https://www.gstatic.com/generate_204',
      if (typeStr == 'urlTest' || typeStr == 'fallback')
        'interval': '${group.interval}s',
      'outbounds': group.proxies.isNotEmpty
          ? group.proxies
          : nodes.map((n) => n.remark).toList(),
    };
  }

  static String _proxyTypeToSingBoxType(ProxyType type) {
    return switch (type) {
      ProxyType.vmess => 'vmess',
      ProxyType.vless => 'vless',
      ProxyType.trojan => 'trojan',
      ProxyType.trojanGo => 'trojan',
      ProxyType.ss => 'shadowsocks',
      ProxyType.ssr => 'shadowsocksr',
      ProxyType.socks5 => 'socks5',
      ProxyType.http => 'http',
      ProxyType.wireguard => 'wireguard',
      ProxyType.hysteria => 'hysteria',
      ProxyType.hysteria2 => 'hysteria2',
      ProxyType.tuic => 'tuic',
      _ => 'direct',
    };
  }

  static Map<String, dynamic> _generateTransport(String type, ProxyNode node) {
    return switch (type) {
      'ws' => {
          'type': 'websocket',
          'path': node.path ?? '/',
          'headers': node.host != null ? {'Host': node.host} : {},
        },
      'grpc' => {
          'type': 'grpc',
          'service_name': node.path ?? '',
          'authority': node.host ?? '',
        },
      'http' => {
          'type': 'http',
          'path': node.path ?? '/',
          'headers': node.host != null ? {'Host': node.host} : {},
        },
      'h2' => {
          'type': 'http',
          'path': node.path ?? '/',
          'host': node.host != null ? [node.host] : [],
        },
      _ => {'type': 'tcp'},
    };
  }

  static Map<String, dynamic> _generateTlsSettings(ProxyNode node) {
    return {
      'enabled': true,
      'server_name': node.sni ?? node.server,
      if (node.fingerprint != null) 'fingerprint': node.fingerprint,
      if (node.alpn != null) 'alpn': node.alpn!.split(','),
    };
  }

  static Map<String, dynamic> _generateDefaultRoute() {
    return {
      'rules': [
        {
          'geosite': 'category-ads-all',
          'outbound_tag': 'block',
        },
        {
          'geosite': 'cn',
          'outbound_tag': 'direct',
        },
        {
          'geoip': 'private',
          'outbound_tag': 'direct',
        },
      ],
      'auto_detect_interface': true,
    };
  }

  static String toJsonString(Map<String, dynamic> config) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config);
  }
}
