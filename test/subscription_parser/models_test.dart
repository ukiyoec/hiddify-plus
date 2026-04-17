import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/subscription_parser/models/models.dart';

void main() {
  group('ProxyNode', () {
    test('should create ProxyNode with required fields', () {
      const node = ProxyNode(
        id: 'test-id',
        remark: 'Test Node',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 8080,
      );

      expect(node.id, 'test-id');
      expect(node.remark, 'Test Node');
      expect(node.type, ProxyType.vmess);
      expect(node.server, 'example.com');
      expect(node.port, 8080);
    });

    test('should create ProxyNode with VMess settings', () {
      const node = ProxyNode(
        id: 'vmess-id',
        remark: 'VMess Node',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 8080,
        userId: 'test-uuid',
        alterId: 0,
        encryptMethod: 'auto',
      );

      expect(node.userId, 'test-uuid');
      expect(node.alterId, 0);
      expect(node.encryptMethod, 'auto');
    });

    test('should create ProxyNode with TLS settings', () {
      const node = ProxyNode(
        id: 'tls-id',
        remark: 'TLS Node',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 443,
        tlsSecure: true,
        sni: 'example.com',
        fingerprint: 'chrome',
      );

      expect(node.tlsSecure, true);
      expect(node.sni, 'example.com');
      expect(node.fingerprint, 'chrome');
    });

    test('should create ProxyNode with network settings', () {
      const node = ProxyNode(
        id: 'network-id',
        remark: 'WS Node',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 443,
        network: 'ws',
        host: 'example.com',
        path: '/v2',
      );

      expect(node.network, 'ws');
      expect(node.host, 'example.com');
      expect(node.path, '/v2');
    });

    test('should generate identifier from remark, server, and port', () {
      const node = ProxyNode(
        id: 'id',
        remark: 'Test Node',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 8080,
      );

      expect(node.identifier, 'Test Node-example.com:8080');
    });

    test('should support copyWith', () {
      const original = ProxyNode(
        id: 'id',
        remark: 'Original',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 8080,
      );

      final copied = original.copyWith(remark: 'Modified', port: 9090);

      expect(copied.remark, 'Modified');
      expect(copied.port, 9090);
      expect(copied.server, 'example.com');
      expect(copied.type, ProxyType.vmess);
    });

    test('should serialize to JSON and back', () {
      const original = ProxyNode(
        id: 'id',
        remark: 'Test Node',
        type: ProxyType.vmess,
        server: 'example.com',
        port: 8080,
        userId: 'test-uuid',
        tlsSecure: true,
      );

      final json = original.toJson();
      final restored = ProxyNode.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.remark, original.remark);
      expect(restored.type, original.type);
      expect(restored.server, original.server);
      expect(restored.port, original.port);
      expect(restored.userId, original.userId);
      expect(restored.tlsSecure, original.tlsSecure);
    });
  });

  group('ProxyType', () {
    test('should convert from string', () {
      expect(ProxyType.fromString('vmess'), ProxyType.vmess);
      expect(ProxyType.fromString('vless'), ProxyType.vless);
      expect(ProxyType.fromString('trojan'), ProxyType.trojan);
      expect(ProxyType.fromString('ss'), ProxyType.ss);
      expect(ProxyType.fromString('unknown'), ProxyType.unknown);
    });

    test('should return key as string', () {
      expect(ProxyType.vmess.key, 'vmess');
      expect(ProxyType.vless.key, 'vless');
      expect(ProxyType.ss.key, 'ss');
    });
  });

  group('ProxyGroup', () {
    test('should create ProxyGroup with required fields', () {
      const group = ProxyGroup(
        name: 'Test Group',
        type: GroupType.select,
        proxies: ['Node 1', 'Node 2'],
      );

      expect(group.name, 'Test Group');
      expect(group.type, GroupType.select);
      expect(group.proxies, ['Node 1', 'Node 2']);
    });

    test('should create ProxyGroup with urlTest settings', () {
      const group = ProxyGroup(
        name: 'Auto Group',
        type: GroupType.urlTest,
        proxies: ['Node 1', 'Node 2'],
        url: 'https://www.gstatic.com/generate_204',
        interval: 300,
        tolerance: 150,
        lazy: true,
      );

      expect(group.url, 'https://www.gstatic.com/generate_204');
      expect(group.interval, 300);
      expect(group.tolerance, 150);
      expect(group.lazy, true);
    });

    test('should convert GroupType to Clash string', () {
      expect(GroupType.select.key, 'select');
      expect(GroupType.urlTest.key, 'urlTest');
      expect(GroupType.fallback.key, 'fallback');
      expect(GroupType.loadBalance.key, 'loadBalance');
      expect(GroupType.relay.key, 'relay');
    });

    test('should serialize to JSON and back', () {
      const original = ProxyGroup(
        name: 'Test Group',
        type: GroupType.select,
        proxies: ['Node 1', 'Node 2'],
        url: 'https://test.com',
        interval: 300,
      );

      final json = original.toJson();
      final restored = ProxyGroup.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.proxies, original.proxies);
      expect(restored.interval, original.interval);
    });
  });

  group('GroupType', () {
    test('should convert from string', () {
      expect(GroupType.fromString('select'), GroupType.select);
      expect(GroupType.fromString('url-test'), GroupType.urlTest);
      expect(GroupType.fromString('fallback'), GroupType.fallback);
      expect(GroupType.fromString('load-balance'), GroupType.loadBalance);
    });

    test('should return key as string', () {
      expect(GroupType.select.key, 'select');
      expect(GroupType.urlTest.key, 'urlTest');
    });

    test('should convert to Clash string format', () {
      expect(GroupType.select.toClashString(), 'select');
      expect(GroupType.urlTest.toClashString(), 'url-test');
      expect(GroupType.fallback.toClashString(), 'fallback');
      expect(GroupType.loadBalance.toClashString(), 'load-balance');
      expect(GroupType.relay.toClashString(), 'relay');
    });
  });

  group('ParsedSubscription', () {
    test('should create with default values', () {
      const subscription = ParsedSubscription(
        nodes: [],
        format: SubscriptionFormat.clash,
      );

      expect(subscription.nodes, isEmpty);
      expect(subscription.groups, isEmpty);
      expect(subscription.format, SubscriptionFormat.clash);
    });

    test('should serialize to JSON and back', () {
      const original = ParsedSubscription(
        nodes: [
          ProxyNode(
            id: '1',
            remark: 'Test',
            type: ProxyType.vmess,
            server: 'example.com',
            port: 8080,
          ),
        ],
        groups: [
          ProxyGroup(
            name: 'Test Group',
            type: GroupType.select,
            proxies: ['Test'],
          ),
        ],
        format: SubscriptionFormat.clash,
      );

      final json = original.toJson();
      final restored = ParsedSubscription.fromJson(json);

      expect(restored.nodes.length, 1);
      expect(restored.groups.length, 1);
      expect(restored.format, SubscriptionFormat.clash);
    });
  });

  group('SubscriptionInfo', () {
    test('should create SubscriptionInfo', () {
      final info = SubscriptionInfo(
        upload: 1024,
        download: 2048,
        total: 10240,
        expire: DateTime(2024, 12, 31),
      );

      expect(info.upload, 1024);
      expect(info.download, 2048);
      expect(info.total, 10240);
      expect(info.expire, DateTime(2024, 12, 31));
    });

    test('should serialize to JSON and back', () {
      final original = SubscriptionInfo(
        upload: 1024,
        download: 2048,
        total: 10240,
        expire: DateTime(2024, 12, 31),
        webPageUrl: 'https://example.com',
        supportUrl: 'https://support.example.com',
      );

      final json = original.toJson();
      final restored = SubscriptionInfo.fromJson(json);

      expect(restored.upload, original.upload);
      expect(restored.download, original.download);
      expect(restored.total, original.total);
      expect(restored.webPageUrl, original.webPageUrl);
    });
  });
}
