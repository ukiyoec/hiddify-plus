import 'dart:convert';
import 'package:hiddify/subscription_parser/models/models.dart';

class V2RayConfigGenerator {
  static Map<String, dynamic> generateConfig({
    required List<ProxyNode> nodes,
    Map<String, dynamic>? logOptions,
    Map<String, dynamic>? dnsOptions,
  }) {
    return {
      'log': logOptions ?? {'loglevel': 'warning'},
      'dns': dnsOptions ?? _generateDns(),
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
      'inbounds': _generateInbounds(),
      'outbounds': _generateOutbounds(nodes),
      'routing': _generateRouting(),
    };
  }

  static List<Map<String, dynamic>> _generateInbounds() {
    return [
      {
        'tag': 'socks-inbound',
        'protocol': 'socks',
        'port': 1080,
        'listen': '127.0.0.1',
        'settings': {
          'auth': 'noauth',
          'udp': true,
        },
      },
      {
        'tag': 'http-inbound',
        'protocol': 'http',
        'port': 10808,
        'listen': '127.0.0.1',
      },
      {
        'tag': 'tun-inbound',
        'protocol': 'dokodemo-door',
        'port': 10888,
        'listen': '10.0.0.1',
        'settings': {
          'network': 'tcp,udp',
          'address': '10.0.0.1',
        },
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls'],
        },
      },
    ];
  }

  static List<Map<String, dynamic>> _generateOutbounds(List<ProxyNode> nodes) {
    final outbounds = <Map<String, dynamic>>[];

    for (final node in nodes) {
      outbounds.add(_proxyNodeToOutbound(node));
    }

    if (outbounds.isEmpty) {
      outbounds.add({
        'tag': 'direct',
        'protocol': 'freedom',
        'settings': {},
      });
    }

    outbounds.add({
      'tag': 'dns-outbound',
      'protocol': 'dns',
      'settings': {},
    });

    return outbounds;
  }

  static Map<String, dynamic> _proxyNodeToOutbound(ProxyNode node) {
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
        outbound['streamSettings'] = _generateStreamSettings(node);
        break;

      case ProxyType.vless:
        outbound['settings'] = {
          'vnext': [
            {
              'address': node.server,
              'port': node.port,
              'users': [
                {
                  'id': node.userId ?? '',
                  'encryption': 'none',
                  'flow': node.transport == 'grpc' ? 'xtls-rprx-vision' : '',
                },
              ],
            },
          ],
        };
        outbound['streamSettings'] = _generateStreamSettings(node);
        if (node.tlsSecure) {
          outbound['streamSettings']!['security'] = 'tls';
          outbound['streamSettings']!['tlsSettings'] = _generateTlsSettings(node);
        }
        break;

      case ProxyType.trojan:
        outbound['settings'] = {
          'servers': [
            {
              'address': node.server,
              'port': node.port,
              'password': node.password ?? '',
            },
          ],
        };
        if (node.tlsSecure) {
          outbound['streamSettings'] = {
            'network': 'tcp',
            'security': 'tls',
            'tlsSettings': _generateTlsSettings(node),
          };
        }
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

      case ProxyType.socks5:
        outbound['settings'] = {
          'servers': [
            {
              'address': node.server,
              'port': node.port,
              if (node.username != null) 'user': node.username,
              if (node.password != null) 'pass': node.password,
            },
          ],
        };
        break;

      case ProxyType.http:
        outbound['settings'] = {
          'servers': [
            {
              'address': node.server,
              'port': node.port,
              if (node.username != null) 'user': node.username,
              if (node.password != null) 'pass': node.password,
            },
          ],
        };
        break;

      default:
        outbound['settings'] = {};
    }

    return outbound;
  }

  static Map<String, dynamic> _generateStreamSettings(ProxyNode node) {
    final network = node.network ?? 'tcp';
    final streamSettings = <String, dynamic>{
      'network': network,
    };

    switch (network) {
      case 'ws':
        streamSettings['wsSettings'] = {
          'path': node.path ?? '/',
          'headers': node.host != null ? {'Host': node.host} : {},
        };
        if (node.tlsSecure) {
          streamSettings['security'] = 'tls';
          streamSettings['tlsSettings'] = _generateTlsSettings(node);
        }
        break;

      case 'h2':
        streamSettings['httpSettings'] = {
          'path': node.path ?? '/',
          'host': node.host != null ? [node.host] : [],
        };
        if (node.tlsSecure) {
          streamSettings['security'] = 'tls';
          streamSettings['tlsSettings'] = _generateTlsSettings(node);
        }
        break;

      case 'grpc':
        streamSettings['grpcSettings'] = {
          'serviceName': node.path ?? '',
          'authority': node.host ?? '',
        };
        if (node.tlsSecure) {
          streamSettings['security'] = 'tls';
          streamSettings['tlsSettings'] = _generateTlsSettings(node);
        }
        break;

      case 'quic':
        streamSettings['quicSettings'] = {
          'security': node.encryptMethod ?? 'none',
          'key': node.password ?? '',
          'header': {
            'type': 'none',
          },
        };
        if (node.tlsSecure) {
          streamSettings['security'] = 'tls';
          streamSettings['tlsSettings'] = _generateTlsSettings(node);
        }
        break;

      default:
        if (node.tlsSecure) {
          streamSettings['security'] = 'tls';
          streamSettings['tlsSettings'] = _generateTlsSettings(node);
        }
    }

    return streamSettings;
  }

  static Map<String, dynamic> _generateTlsSettings(ProxyNode node) {
    return {
      'serverName': node.sni ?? node.server,
      if (node.fingerprint != null) 'fingerprint': node.fingerprint,
      if (node.alpn != null) 'alpn': node.alpn!.split(','),
    };
  }

  static String _proxyTypeToV2RayProtocol(ProxyType type) {
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

  static Map<String, dynamic> _generateDns() {
    return {
      'servers': [
        {
          'address': 'tls://8.8.8.8',
          'port': 443,
          'domains': ['domain:google.com', 'domain:googleapis.com'],
        },
        {
          'address': 'tls://1.1.1.1',
          'port': 443,
          'domains': ['domain:cloudflare.com'],
        },
        '8.8.8.8',
        '1.1.1.1',
      ],
    };
  }

  static Map<String, dynamic> _generateRouting() {
    return {
      'domainStrategy': 'IPIfNonMatch',
      'rules': [
        {
          'type': 'field',
          'ip': ['geoip:cn', 'geoip:private'],
          'outboundTag': 'direct',
        },
        {
          'type': 'field',
          'domain': ['geosite:cn'],
          'outboundTag': 'direct',
        },
      ],
    };
  }

  static String toJsonString(Map<String, dynamic> config) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config);
  }
}
