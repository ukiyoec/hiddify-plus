import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:hiddify/subscription_parser/parsers/parsers.dart';
import 'package:hiddify/subscription_parser/services/converter.dart';
import 'package:hiddify/kernel_updater/kernel_version_info.dart';
import 'package:hiddify/kernels/kernel_manager.dart';

void main() {
  late SubscriptionConverter converter;

  setUp(() {
    converter = SubscriptionConverter();
  });

  group('完整订阅解析流程', () {
    test('应解析 Clash 订阅并转换为 sing-box 配置', () {
      const clashContent = '''
proxies:
  - name: "SS Node"
    type: ss
    server: example.com
    port: 8388
    cipher: aes-256-gcm
    password: password123
  - name: "VMess Node"
    type: vmess
    server: example2.com
    port: 8080
    uuid: test-uuid
    alterId: 0
    cipher: auto
''';

      final parsed = ParserFactory.parse(clashContent);
      expect(parsed.nodes.length, 2);
      expect(parsed.format, SubscriptionFormat.clash);

      final singboxConfig = converter.nodesToKernel(
        parsed.nodes,
        targetKernel: KernelType.singBox,
      );

      expect(singboxConfig, contains('"tag": "SS Node"'));
      expect(singboxConfig, contains('"tag": "VMess Node"'));
      expect(singboxConfig, contains('"type": "shadowsocks"'));
      expect(singboxConfig, contains('"type": "vmess"'));
    });

    test('应解析 sing-box JSON 并转换为 Clash.Meta 配置', () {
      const singboxContent = '''
{
  "outbounds": [
    {
      "tag": "Test Node",
      "type": "vmess",
      "server": "example.com",
      "server_port": 8080,
      "uuid": "test-uuid",
      "alterId": 0
    }
  ]
}
''';

      final parsed = ParserFactory.parse(singboxContent);
      expect(parsed.nodes.length, 1);
      expect(parsed.format, SubscriptionFormat.singbox);

      final clashConfig = converter.nodesToKernel(
        parsed.nodes,
        targetKernel: KernelType.clashMeta,
      );

      expect(clashConfig, contains('name: "Test Node"'));
      expect(clashConfig, contains('type: vmess'));
      expect(clashConfig, contains('server: example.com'));
    });

    test('应解析 VMess URI 并转换为 V2Ray 配置', () {
      const vmessUri = 'vmess://eyJ2IjoiMiIsInBzIjoiVGVzdCIsImFkZCI6ImV4YW1wbGUuY29tIiwicG9ydCI6IjgwODAiLCJpZCI6IjEyMzQ1Njc4LTEyMzQtMTIzNC0xMjM0LTEyMzQ1Njc4OTAiLCJhaWQiOiIwIiwibmV0IjoidGNwIiwidHlwZSI6Im5vbmUifQ==@example.com:8080';

      final parsed = ParserFactory.parse(vmessUri);
      expect(parsed.nodes.length, 1);
      expect(parsed.format, SubscriptionFormat.vmess);

      final v2rayConfig = converter.nodesToKernel(
        parsed.nodes,
        targetKernel: KernelType.v2ray,
      );

      // V2Ray 配置是完整 JSON，ps 字段在 outbounds 中
      expect(v2rayConfig, contains('"outbounds"'));
    });

    test('应合并多个订阅', () {
      const content1 = '''
proxies:
  - name: "Node 1"
    type: ss
    server: server1.com
    port: 8388
''';
      const content2 = '''
proxies:
  - name: "Node 2"
    type: vmess
    server: server2.com
    port: 8080
    uuid: test-uuid
    alterId: 0
''';

      final merged = converter.mergeSubscriptions([content1, content2]);
      expect(merged.length, 2);
    });

    test('应按协议类型分割节点', () {
      final nodes = [
        const ProxyNode(
          id: '1',
          remark: 'SS Node',
          type: ProxyType.ss,
          server: 'example.com',
          port: 8388,
        ),
        const ProxyNode(
          id: '2',
          remark: 'VMess Node',
          type: ProxyType.vmess,
          server: 'example.com',
          port: 8080,
        ),
        const ProxyNode(
          id: '3',
          remark: 'SS Node 2',
          type: ProxyType.ss,
          server: 'example2.com',
          port: 8389,
        ),
      ];

      final split = converter.splitByProtocol(nodes);

      expect(split['ss']?.length, 2);
      expect(split['vmess']?.length, 1);
    });

    test('应按名称过滤节点', () {
      final nodes = [
        const ProxyNode(
          id: '1',
          remark: 'US Server 1',
          type: ProxyType.ss,
          server: 'us.example.com',
          port: 8388,
        ),
        const ProxyNode(
          id: '2',
          remark: 'HK Server 1',
          type: ProxyType.ss,
          server: 'hk.example.com',
          port: 8388,
        ),
        const ProxyNode(
          id: '3',
          remark: 'US Server 2',
          type: ProxyType.ss,
          server: 'us2.example.com',
          port: 8388,
        ),
      ];

      final filtered = converter.filterByName(nodes, 'US');
      expect(filtered.length, 2);
    });
  });

  group('内核配置生成', () {
    test('应为 sing-box 生成完整配置', () {
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

      final json = parseJson(config);

      expect(json['log'], isNotNull);
      expect(json['dns'], isNotNull);
      expect(json['inbounds'], isNotNull);
      expect(json['outbounds'], isNotNull);
      expect(json['route'], isNotNull);

      final outbounds = json['outbounds'] as List;
      expect(outbounds.any((o) => o['tag'] == 'Test Node'), true);
    });

    test('应为 Clash.Meta 生成完整配置', () {
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

      expect(config, contains('mixed-port:'));
      expect(config, contains('proxies:'));
      expect(config, contains('proxy-groups:'));
      expect(config, contains('rules:'));
    });

    test('应为 V2Ray 生成完整配置', () {
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

      final json = parseJson(config);

      expect(json['log'], isNotNull);
      expect(json['dns'], isNotNull);
      expect(json['inbounds'], isNotNull);
      expect(json['outbounds'], isNotNull);
      expect(json['routing'], isNotNull);
    });
  });

  group('代理组生成', () {
    test('应为节点生成默认代理组', () {
      final nodes = [
        const ProxyNode(
          id: '1',
          remark: 'Node 1',
          type: ProxyType.ss,
          server: 'server1.com',
          port: 8388,
        ),
        const ProxyNode(
          id: '2',
          remark: 'Node 2',
          type: ProxyType.ss,
          server: 'server2.com',
          port: 8388,
        ),
      ];

      final groups = converter.generateDefaultGroups(nodes);

      // 默认生成 3 个组: auto (urlTest), proxy (select), fallback (fallback)
      expect(groups.length, 3);
      expect(groups[0].name, 'auto');
      expect(groups[0].type, GroupType.urlTest);
      expect(groups[1].name, 'proxy');
      expect(groups[1].type, GroupType.select);
    });

    test('应为空列表生成空代理组', () {
      final groups = converter.generateDefaultGroups([]);
      expect(groups, isEmpty);
    });
  });

  group('格式检测', () {
    test('应正确检测各种格式', () {
      expect(
        FormatDetector.detect('vmess://xxx'),
        SubscriptionFormat.vmess,
      );
      expect(
        FormatDetector.detect('vless://xxx'),
        SubscriptionFormat.vless,
      );
      expect(
        FormatDetector.detect('trojan://xxx'),
        SubscriptionFormat.trojan,
      );
      expect(
        FormatDetector.detect('ss://xxx'),
        SubscriptionFormat.ss,
      );
      expect(
        FormatDetector.detect('proxies:\n  - name: test'),
        SubscriptionFormat.clash,
      );
      expect(
        FormatDetector.detect('{"outbounds": []}'),
        SubscriptionFormat.singbox,
      );
      expect(
        FormatDetector.detect('{"v": "2", "ps": "test"}'),
        SubscriptionFormat.v2ray,
      );
    });
  });
}

Map<String, dynamic> parseJson(String content) {
  final lines = content.split('\n');
  final jsonLines = lines.where((l) => !l.trim().startsWith('//') && l.trim().isNotEmpty);
  return jsonDecode(jsonLines.join('\n')) as Map<String, dynamic>;
}