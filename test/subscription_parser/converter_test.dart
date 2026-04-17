import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:hiddify/subscription_parser/services/converter.dart';
import 'package:hiddify/kernel_updater/kernel_version_info.dart';

void main() {
  group('SubscriptionConverter', () {
    late SubscriptionConverter converter;

    setUp(() {
      converter = SubscriptionConverter();
    });

    group('detectInputFormat', () {
      test('should detect Clash YAML format', () {
        const clashContent = '''
proxies:
  - name: "test"
    type: ss
    server: example.com
    port: 8388
''';
        final format = converter.detectInputFormat(clashContent);
        expect(format, SubscriptionFormat.clash);
      });

      test('should detect sing-box JSON format', () {
        const singboxContent = '''
{
  "outbounds": [
    {"tag": "direct", "type": "direct"}
  ]
}
''';
        final format = converter.detectInputFormat(singboxContent);
        expect(format, SubscriptionFormat.singbox);
      });

      test('should detect VMess URI format', () {
        const uriContent = 'vmess://eyJhbGciOiJub25lIiwidHlwZSI6Im5vbmUifQ==@example.com:8080';
        final format = converter.detectInputFormat(uriContent);
        expect(format, SubscriptionFormat.vmess);
      });
    });

    group('generateDefaultGroups', () {
      test('should generate default groups for empty nodes', () {
        final groups = converter.generateDefaultGroups([]);
        expect(groups, isEmpty);
      });

      test('should generate proxy, auto, and fallback groups', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'Node 1',
            type: ProxyType.vmess,
            server: 'server1.com',
            port: 8080,
          ),
          const ProxyNode(
            id: '2',
            remark: 'Node 2',
            type: ProxyType.vless,
            server: 'server2.com',
            port: 443,
          ),
        ];

        final groups = converter.generateDefaultGroups(nodes);

        expect(groups.length, 3);
        expect(groups[0].name, 'auto');
        expect(groups[0].type, GroupType.urlTest);
        expect(groups[1].name, 'proxy');
        expect(groups[1].type, GroupType.select);
        expect(groups[2].name, 'fallback');
        expect(groups[2].type, GroupType.fallback);
      });

      test('should include all nodes in proxy group', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'Node 1',
            type: ProxyType.vmess,
            server: 'server1.com',
            port: 8080,
          ),
          const ProxyNode(
            id: '2',
            remark: 'Node 2',
            type: ProxyType.vless,
            server: 'server2.com',
            port: 443,
          ),
        ];

        final groups = converter.generateDefaultGroups(nodes);

        expect(groups[1].proxies, containsAll(['DIRECT', 'Node 1', 'Node 2']));
      });
    });

    group('mergeSubscriptions', () {
      test('should merge nodes from multiple subscriptions', () {
        final contents = [
          '''
proxies:
  - name: "Node1"
    type: ss
    server: server1.com
    port: 8388
''',
          '''
proxies:
  - name: "Node2"
    type: vmess
    server: server2.com
    port: 8080
''',
        ];

        final mergedNodes = converter.mergeSubscriptions(contents);

        expect(mergedNodes.length, 2);
        expect(mergedNodes.any((n) => n.remark == 'Node1'), true);
        expect(mergedNodes.any((n) => n.remark == 'Node2'), true);
      });

      test('should remove duplicate nodes by server:port', () {
        final contents = [
          '''
proxies:
  - name: "Node1"
    type: ss
    server: server1.com
    port: 8388
''',
          '''
proxies:
  - name: "Node1-Dup"
    type: ss
    server: server1.com
    port: 8388
''',
        ];

        final mergedNodes = converter.mergeSubscriptions(contents);

        expect(mergedNodes.length, 1);
      });
    });

    group('splitByProtocol', () {
      test('should split nodes by protocol type', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'VMess Node',
            type: ProxyType.vmess,
            server: 'server1.com',
            port: 8080,
          ),
          const ProxyNode(
            id: '2',
            remark: 'VLESS Node',
            type: ProxyType.vless,
            server: 'server2.com',
            port: 443,
          ),
          const ProxyNode(
            id: '3',
            remark: 'Another VMess',
            type: ProxyType.vmess,
            server: 'server3.com',
            port: 8080,
          ),
        ];

        final split = converter.splitByProtocol(nodes);

        expect(split['vmess']!.length, 2);
        expect(split['vless']!.length, 1);
      });
    });

    group('filterByProtocol', () {
      test('should filter nodes by allowed protocol types', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'VMess Node',
            type: ProxyType.vmess,
            server: 'server1.com',
            port: 8080,
          ),
          const ProxyNode(
            id: '2',
            remark: 'VLESS Node',
            type: ProxyType.vless,
            server: 'server2.com',
            port: 443,
          ),
          const ProxyNode(
            id: '3',
            remark: 'Trojan Node',
            type: ProxyType.trojan,
            server: 'server3.com',
            port: 443,
          ),
        ];

        final filtered = converter.filterByProtocol(
          nodes,
          {ProxyType.vmess, ProxyType.vless},
        );

        expect(filtered.length, 2);
        expect(filtered.every((n) => n.type == ProxyType.vmess || n.type == ProxyType.vless), true);
      });
    });

    group('filterByName', () {
      test('should filter nodes by keyword in name or server', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'US Server 1',
            type: ProxyType.vmess,
            server: 'us.example.com',
            port: 8080,
          ),
          const ProxyNode(
            id: '2',
            remark: 'JP Server',
            type: ProxyType.vless,
            server: 'jp.example.com',
            port: 443,
          ),
          const ProxyNode(
            id: '3',
            remark: 'HK Server',
            type: ProxyType.trojan,
            server: 'hk.example.com',
            port: 443,
          ),
        ];

        final filtered = converter.filterByName(nodes, 'US');

        expect(filtered.length, 1);
        expect(filtered.first.remark, 'US Server 1');
      });

      test('should be case insensitive', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'US Server',
            type: ProxyType.vmess,
            server: 'server.com',
            port: 8080,
          ),
        ];

        final filtered = converter.filterByName(nodes, 'us');

        expect(filtered.length, 1);
      });
    });

    group('nodesToKernel', () {
      test('should generate sing-box config', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'Test Node',
            type: ProxyType.vmess,
            server: 'example.com',
            port: 8080,
            userId: 'test-uuid',
          ),
        ];

        final config = converter.nodesToKernel(
          nodes,
          targetKernel: KernelType.singBox,
        );

        expect(config, contains('"tag": "Test Node"'));
        expect(config, contains('"type": "vmess"'));
        expect(config, contains('"server": "example.com"'));
      });

      test('should generate Clash.Meta config', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'Test Node',
            type: ProxyType.vmess,
            server: 'example.com',
            port: 8080,
            userId: 'test-uuid',
          ),
        ];

        final config = converter.nodesToKernel(
          nodes,
          targetKernel: KernelType.clashMeta,
        );

        expect(config, contains('name: "Test Node"'));
        expect(config, contains('type: vmess'));
        expect(config, contains('server: example.com'));
        expect(config, contains('port: 8080'));
      });

      test('should generate V2Ray config', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'Test Node',
            type: ProxyType.vmess,
            server: 'example.com',
            port: 8080,
            userId: 'test-uuid',
          ),
        ];

        final config = converter.nodesToKernel(
          nodes,
          targetKernel: KernelType.v2ray,
        );

        expect(config, contains('"tag": "Test Node"'));
        expect(config, contains('"protocol": "vmess"'));
      });

      test('should use custom groups if provided', () {
        final nodes = [
          const ProxyNode(
            id: '1',
            remark: 'Test Node',
            type: ProxyType.vmess,
            server: 'example.com',
            port: 8080,
          ),
        ];

        final customGroups = [
          const ProxyGroup(
            name: 'custom',
            type: GroupType.select,
            proxies: ['Test Node'],
          ),
        ];

        final config = converter.nodesToKernel(
          nodes,
          targetKernel: KernelType.clashMeta,
          groups: customGroups,
        );

        expect(config, contains('name: "custom"'));
      });
    });
  });
}
