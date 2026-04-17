import 'dart:convert';
import 'package:hiddify/subscription_parser/models/models.dart';

class ClashMetaConfigGenerator {
  static String generateConfig({
    required List<ProxyNode> nodes,
    required List<ProxyGroup> groups,
    Map<String, dynamic>? globalOptions,
  }) {
    final config = <String, dynamic>{
      'mixed-port': 7890,
      'allow-lan': false,
      'mode': 'rule',
      'log-level': 'info',
      'external-controller': '127.0.0.1:9090',
    };

    if (globalOptions != null) {
      config.addAll(globalOptions);
    }

    config['proxies'] = nodes.map(_proxyNodeToClashProxy).toList();
    config['proxy-groups'] = groups.map((g) => _proxyGroupToClashGroup(g, nodes)).toList();

    final rules = <String>[
      'GEOIP,CN,DIRECT',
      'MATCH,auto',
    ];
    config['rules'] = rules;

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config);
  }

  static Map<String, dynamic> _proxyNodeToClashProxy(ProxyNode node) {
    final proxy = <String, dynamic>{
      'name': node.remark,
      'type': _proxyTypeToClashType(node.type),
      'server': node.server,
      'port': node.port,
    };

    switch (node.type) {
      case ProxyType.vmess:
        proxy['uuid'] = node.userId ?? '';
        proxy['alterId'] = node.alterId ?? 0;
        proxy['cipher'] = node.encryptMethod ?? 'auto';
        if (node.network != null) {
          proxy['network'] = node.network;
        }
        if (node.tlsSecure) {
          proxy['tls'] = true;
        }
        if (node.sni != null) {
          proxy['servername'] = node.sni;
        }
        break;

      case ProxyType.vless:
        proxy['uuid'] = node.userId ?? '';
        if (node.tlsSecure) {
          proxy['tls'] = true;
          if (node.fingerprint != null) {
            proxy['fingerprint'] = node.fingerprint;
          }
          if (node.alpn != null) {
            proxy['alpn'] = node.alpn!.split(',');
          }
        }
        if (node.sni != null) {
          proxy['servername'] = node.sni;
        }
        if (node.network != null) {
          proxy['network'] = node.network;
        }
        break;

      case ProxyType.trojan:
        proxy['password'] = node.password ?? '';
        if (node.tlsSecure) {
          proxy['tls'] = true;
          if (node.sni != null) {
            proxy['sni'] = node.sni;
          }
          if (node.fingerprint != null) {
            proxy['fingerprint'] = node.fingerprint;
          }
        }
        break;

      case ProxyType.ss:
        proxy['cipher'] = node.encryptMethod ?? 'chacha20-ietf-poly1305';
        proxy['password'] = node.password ?? '';
        break;

      case ProxyType.ssr:
        proxy['cipher'] = node.encryptMethod ?? 'chacha20-ietf';
        proxy['password'] = node.password ?? '';
        proxy['obfs'] = node.obfs ?? 'plain';
        proxy['obfs-param'] = node.obfsParam ?? '';
        proxy['protocol'] = node.protocolParam ?? 'origin';
        proxy['protocol-param'] = '';
        break;

      case ProxyType.hysteria:
      case ProxyType.hysteria2:
        proxy['auth_str'] = node.password ?? '';
        if (node.upSpeed != null) {
          proxy['up'] = node.upSpeed;
        }
        if (node.downSpeed != null) {
          proxy['down'] = node.downSpeed;
        }
        break;

      case ProxyType.socks5:
        if (node.username != null) {
          proxy['username'] = node.username;
        }
        if (node.password != null) {
          proxy['password'] = node.password;
        }
        break;

      case ProxyType.http:
        if (node.username != null) {
          proxy['username'] = node.username;
        }
        if (node.password != null) {
          proxy['password'] = node.password;
        }
        break;

      default:
        break;
    }

    if (node.network != null && _supportsTransport(node.type)) {
      proxy['network'] = node.network;
      if (node.network == 'ws' || node.network == 'h2') {
        if (node.path != null) {
          proxy['ws-path'] = node.path;
        }
        if (node.host != null) {
          proxy['ws-headers'] = {'Host': node.host};
        }
      }
      if (node.network == 'grpc') {
        if (node.path != null) {
          proxy['grpc-service-name'] = node.path;
        }
      }
    }

    return proxy;
  }

  static Map<String, dynamic> _proxyGroupToClashGroup(
    ProxyGroup group,
    List<ProxyNode> nodes,
  ) {
    final typeStr = group.type == GroupType.urlTest
        ? 'url-test'
        : group.type.key;

    final clashGroup = <String, dynamic>{
      'name': group.name,
      'type': typeStr,
      'proxies': group.proxies.isNotEmpty
          ? group.proxies
          : nodes.map((n) => n.remark).toList(),
    };

    if (group.type == GroupType.urlTest || group.type == GroupType.fallback) {
      clashGroup['url'] = group.url ?? 'https://www.gstatic.com/generate_204';
      clashGroup['interval'] = group.interval;
      clashGroup['tolerance'] = group.tolerance;
    }

    if (group.type == GroupType.loadBalance) {
      clashGroup['url'] = group.url ?? 'https://www.gstatic.com/generate_204';
      clashGroup['interval'] = group.interval;
    }

    if (group.lazy) {
      clashGroup['lazy'] = true;
    }

    if (group.disableUdp) {
      clashGroup['disable-udp'] = true;
    }

    return clashGroup;
  }

  static String _proxyTypeToClashType(ProxyType type) {
    return switch (type) {
      ProxyType.vmess => 'vmess',
      ProxyType.vless => 'vless',
      ProxyType.trojan => 'trojan',
      ProxyType.trojanGo => 'trojan',
      ProxyType.ss => 'ss',
      ProxyType.ssr => 'ssr',
      ProxyType.socks5 => 'socks5',
      ProxyType.http => 'http',
      ProxyType.hysteria => 'hysteria',
      ProxyType.hysteria2 => 'hysteria2',
      ProxyType.tuic => 'tuic',
      ProxyType.wireguard => 'wireguard',
      _ => 'direct',
    };
  }

  static bool _supportsTransport(ProxyType type) {
    return type == ProxyType.vmess ||
        type == ProxyType.vless ||
        type == ProxyType.trojan ||
        type == ProxyType.http;
  }
}
