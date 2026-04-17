import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:hiddify/subscription_parser/parsers/parsers.dart';

void main() {
  group('FormatDetector', () {
    test('should detect Clash YAML format', () {
      const content = '''
proxies:
  - name: "test"
    type: ss
    server: example.com
    port: 8388
    cipher: aes-256-gcm
    password: password123
''';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.clash);
    });

    test('should detect sing-box JSON format', () {
      const content = '''
{
  "outbounds": [
    {"tag": "direct", "type": "direct"}
  ]
}
''';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.singbox);
    });

    test('should detect V2Ray JSON format', () {
      const content = '''
{
  "v": "2",
  "ps": "Test Node",
  "add": "example.com",
  "port": "8080",
  "id": "test-uuid",
  "aid": "0",
  "net": "tcp",
  "type": "none"
}
''';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.v2ray);
    });

    test('should detect VMess URI', () {
      const content = 'vmess://eyJ2IjoiMiIsInBzIjoiVGVzdCIsImFkZCI6ImV4YW1wbGUuY29tIiwicG9ydCI6IjgwODAiLCJpZCI6IjEyMzQ1Njc4LTEyMzQtMTIzNC0xMjM0LTEyMzQ1Njc4OTAiLCJhaWQiOiIwIiwibmV0IjoidGNwIiwidHlwZSI6Im5vbmUifQ==@example.com:8080';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.vmess);
    });

    test('should detect VLESS URI', () {
      const content = 'vless://test-uuid@example.com:443?encryption=none';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.vless);
    });

    test('should detect Trojan URI', () {
      const content = 'trojan://password@example.com:443';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.trojan);
    });

    test('should detect SS URI', () {
      const content = 'ss://aes-256-gcm:password@example.com:8388';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.ss);
    });

    test('should return unknown for invalid content', () {
      const content = 'invalid content';
      final format = FormatDetector.detect(content);
      expect(format, SubscriptionFormat.unknown);
    });
  });

  group('ClashParser', () {
    late ClashParser parser;

    setUp(() {
      parser = ClashParser();
    });

    test('should parse Clash YAML content', () {
      const content = '''
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
      final result = parser.parse(content);

      expect(result.nodes.length, 2);
      expect(result.nodes[0].remark, 'SS Node');
      expect(result.nodes[0].type, ProxyType.ss);
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 8388);
      expect(result.nodes[1].remark, 'VMess Node');
      expect(result.nodes[1].type, ProxyType.vmess);
    });

    test('should generate Clash YAML', () {
      final nodes = [
        const ProxyNode(
          id: '1',
          remark: 'Test Node',
          type: ProxyType.ss,
          server: 'example.com',
          port: 8388,
          encryptMethod: 'aes-256-gcm',
          password: 'password123',
        ),
      ];

      final generated = parser.generate(nodes);

      expect(generated, contains('name: "Test Node"'));
      expect(generated, contains('type: ss'));
      expect(generated, contains('server: example.com'));
      expect(generated, contains('port: 8388'));
    });
  });

  group('SingBoxParser', () {
    late SingBoxParser parser;

    setUp(() {
      parser = SingBoxParser();
    });

    test('should parse sing-box JSON content', () {
      const content = '''
{
  "outbounds": [
    {
      "tag": "Test Node",
      "type": "shadowsocks",
      "server": "example.com",
      "server_port": 8388,
      "method": "aes-256-gcm",
      "password": "password123"
    }
  ]
}
''';
      final result = parser.parse(content);

      expect(result.nodes.length, 1);
      expect(result.nodes[0].remark, 'Test Node');
      expect(result.nodes[0].type, ProxyType.ss);
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 8388);
    });

    test('should generate sing-box JSON', () {
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

      final generated = parser.generate(nodes);

      expect(generated, contains('"tag": "Test Node"'));
      expect(generated, contains('"type": "vmess"'));
    });
  });

  group('V2RayParser', () {
    late V2RayParser parser;

    setUp(() {
      parser = V2RayParser();
    });

    test('should parse V2Ray JSON content', () {
      const content = '''
{"v":"2","ps":"Test Node","add":"example.com","port":"8080","id":"test-uuid","aid":"0","net":"tcp","type":"none"}
''';
      final result = parser.parse(content);

      expect(result.nodes.length, 1);
      expect(result.nodes[0].remark, 'Test Node');
      expect(result.nodes[0].type, ProxyType.vmess);
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 8080);
    });

    test('should generate V2Ray JSON', () {
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

      final generated = parser.generate(nodes);

      expect(generated, contains('"ps":"Test Node"'));
      expect(generated, contains('"v":"2"'));
    });
  });

  group('UriParser', () {
    late UriParser parser;

    setUp(() {
      parser = UriParser();
    });

    test('should parse VMess URI', () {
      const uri = 'vmess://eyJ2IjoiMiIsInBzIjoiVGVzdCIsImFkZCI6ImV4YW1wbGUuY29tIiwicG9ydCI6IjgwODAiLCJpZCI6IjEyMzQ1Njc4LTEyMzQtMTIzNC0xMjM0LTEyMzQ1Njc4OTAiLCJhaWQiOiIwIiwibmV0IjoidGNwIiwidHlwZSI6Im5vbmUifQ==@example.com:8080';

      final result = parser.parse(uri);

      expect(result.nodes.length, 1);
      expect(result.nodes[0].type, ProxyType.vmess);
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 8080);
    });

    test('should parse VLESS URI', () {
      const uri = 'vless://test-uuid@example.com:443?encryption=none&flow=xtls-rprx-vision';

      final result = parser.parse(uri);

      expect(result.nodes.length, 1);
      expect(result.nodes[0].type, ProxyType.vless);
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 443);
    });

    test('should parse Trojan URI', () {
      const uri = 'trojan://password@example.com:443?allowInsecure=1';

      final result = parser.parse(uri);

      expect(result.nodes.length, 1);
      expect(result.nodes[0].type, ProxyType.trojan);
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 443);
    });

    test('should parse SS URI', () {
      const uri = 'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@example.com:8388#Example';

      final result = parser.parse(uri);

      expect(result.nodes.length, 1);
      expect(result.nodes[0].type, ProxyType.ss);
      expect(result.nodes[0].remark, 'Example');
      expect(result.nodes[0].server, 'example.com');
      expect(result.nodes[0].port, 8388);
    });
  });

  group('ParserFactory', () {
    test('should detect format and parse correctly', () {
      const content = '''
proxies:
  - name: "Test"
    type: ss
    server: example.com
    port: 8388
''';
      final result = ParserFactory.parse(content);

      expect(result.nodes.length, 1);
      expect(result.format, SubscriptionFormat.clash);
    });

    test('should parse with specified format', () {
      const content = '''
proxies:
  - name: "Test"
    type: ss
    server: example.com
    port: 8388
''';
      final result = ParserFactory.parseWithFormat(content, SubscriptionFormat.clash);

      expect(result.nodes.length, 1);
    });

    test('should generate to specified format', () {
      final nodes = [
        const ProxyNode(
          id: '1',
          remark: 'Test',
          type: ProxyType.ss,
          server: 'example.com',
          port: 8388,
        ),
      ];

      final clashConfig = ParserFactory.generate(nodes, targetFormat: SubscriptionFormat.clash);
      expect(clashConfig, contains('name: "Test"'));

      final singboxConfig = ParserFactory.generate(nodes, targetFormat: SubscriptionFormat.singbox);
      expect(singboxConfig, contains('"tag": "Test"'));
    });

    test('should validate format correctly', () {
      const validContent = '''
proxies:
  - name: "Test"
    type: ss
''';
      expect(ParserFactory.isValidFormat(validContent), true);

      const invalidContent = 'invalid content';
      expect(ParserFactory.isValidFormat(invalidContent), false);
    });
  });
}
