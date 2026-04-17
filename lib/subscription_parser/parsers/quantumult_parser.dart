import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class QuantumultParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.quan;
  
  @override
  bool canParse(String content) {
    final trimmed = content.trim();
    return trimmed.contains('[server_local]') || 
           trimmed.contains('vmess://') ||
           trimmed.contains('shadowsocks://');
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid Quantumult format');
    }
    
    final lines = content.split('\n');
    final List<ProxyNode> nodes = [];
    final List<ProxyGroup> groups = [];
    
    String? currentSection;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;
      
      // 检测节头
      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1);
        continue;
      }
      
      if (currentSection == 'server_local' || currentSection == 'server_remote') {
        final node = _parseNodeLine(line);
        if (node != null) nodes.add(node);
      } else if (currentSection == 'server_group') {
        final group = _parseGroupLine(line);
        if (group != null) groups.add(group);
      }
    }
    
    return ParsedSubscription(
      nodes: nodes,
      groups: groups,
      format: SubscriptionFormat.quan,
    );
  }
  
  ProxyNode? _parseNodeLine(String line) {
    try {
      // Quantumult 支持多种 URI 格式
      if (line.startsWith('vmess://')) {
        return _parseVmess(line);
      } else if (line.startsWith('shadowsocks://') || line.startsWith('ss://')) {
        return _parseShadowsocks(line);
      } else if (line.startsWith('shadowsocksr://') || line.startsWith('ssr://')) {
        return _parseShadowsocksR(line);
      } else if (line.startsWith('trojan://')) {
        return _parseTrojan(line);
      } else if (line.startsWith('vless://')) {
        return _parseVless(line);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseVmess(String line) {
    try {
      final withoutScheme = line.substring('vmess://'.length);
      final jsonStr = _base64Decode(withoutScheme);
      if (jsonStr == null) return null;
      
      // Quantumult 的 VMess 可能不是标准 JSON 格式，需要解析 URI 参数
      // 格式: server=xxx&port=xxx&protocol=vmess&...
      if (jsonStr.contains('=')) {
        final params = _parseQueryString(jsonStr);
        return ProxyNode(
          id: _uuid.v4(),
          remark: params['remark'] ?? 'VMess',
          type: ProxyType.vmess,
          server: params['server'] ?? '',
          port: int.tryParse(params['port'] ?? '0') ?? 0,
          userId: params['userId'] ?? params['id'] ?? '',
          alterId: int.tryParse(params['alterId'] ?? params['aid'] ?? '0']),
          network: params['network'] ?? 'tcp',
          host: params['host'],
          path: params['path'],
          tlsSecure: params['tls'] == 'tls' || params['tls'] == 'true',
          sni: params['sni'] ?? params['peer'],
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseShadowsocks(String line) {
    try {
      String cleaned = line;
      if (cleaned.startsWith('shadowsocks://')) {
        cleaned = cleaned.substring('shadowsocks://'.length);
      } else if (cleaned.startsWith('ss://')) {
        cleaned = cleaned.substring('ss://'.length);
      }
      
      final parts = cleaned.split(',');
      if (parts.length < 3) return null;
      
      final server = parts[0];
      final port = int.tryParse(parts[1]) ?? 0;
      final method = parts.length > 2 ? parts[2] : 'aes-256-cfb';
      final password = parts.length > 3 ? parts[3] : '';
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: 'SS-$server:$port',
        type: ProxyType.ss,
        server: server,
        port: port,
        username: method,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseShadowsocksR(String line) {
    try {
      final withoutScheme = line.substring('shadowsocksr://'.length);
      final decoded = _base64Decode(withoutScheme);
      if (decoded == null) return null;
      
      // SSR 格式: method:password:protocol:obfs:url_base64(server:port:protocol_param:obfs_param)
      final parts = decoded.split(':');
      if (parts.length < 5) return null;
      
      final method = parts[0];
      final password = parts[1];
      final protocol = parts[2];
      final obfs = parts[3];
      
      String serverInfo = parts.sublist(4).join(':');
      if (serverInfo.contains('#')) {
        serverInfo = serverInfo.substring(0, serverInfo.indexOf('#'));
      }
      
      String server;
      int port;
      String? protocolParam;
      String? obfsParam;
      
      try {
        final serverDecoded = _base64Decode(serverInfo);
        if (serverDecoded == null) return null;
        
        final serverParts = serverDecoded.split(':');
        if (serverParts.length >= 2) {
          server = serverParts[0];
          port = int.tryParse(serverParts[1]) ?? 0;
          if (serverParts.length >= 3) protocolParam = serverParts[2];
          if (serverParts.length >= 4) obfsParam = serverParts[3];
        } else {
          return null;
        }
      } catch (_) {
        return null;
      }
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: 'SSR-$server:$port',
        type: ProxyType.ssr,
        server: server,
        port: port,
        username: method,
        password: password,
        protocolParam: protocolParam,
        obfs: obfs,
        obfsParam: obfsParam,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseTrojan(String line) {
    try {
      final withoutScheme = line.substring('trojan://'.length);
      final parts = withoutScheme.split('@');
      if (parts.length < 2) return null;
      
      final password = parts[0];
      final rest = parts[1];
      
      final serverParts = rest.split(':');
      if (serverParts.length < 2) return null;
      
      final server = serverParts[0];
      final port = int.tryParse(serverParts[1]) ?? 0;
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: 'Trojan-$server:$port',
        type: ProxyType.trojan,
        server: server,
        port: port,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseVless(String line) {
    try {
      final withoutScheme = line.substring('vless://'.length);
      final parts = withoutScheme.split('@');
      if (parts.length < 2) return null;
      
      final uuid = parts[0];
      final rest = parts[1];
      
      final serverParts = rest.split(':');
      if (serverParts.length < 2) return null;
      
      final server = serverParts[0];
      final port = int.tryParse(serverParts[1]) ?? 0;
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: 'VLESS-$server:$port',
        type: ProxyType.vless,
        server: server,
        port: port,
        userId: uuid,
      );
    } catch (_) {
      return null;
    }
  }
  
  Map<String, String> _parseQueryString(String query) {
    final params = <String, String>{};
    for (final pair in query.split('&')) {
      final kv = pair.split('=');
      if (kv.length == 2) {
        params[kv[0]] = kv[1];
      }
    }
    return params;
  }
  
  String? _base64Decode(String input) {
    try {
      // 移除可能存在的 padding
      String base64 = input;
      if (!base64.endsWith('=')) {
        final padding = (4 - base64.length % 4) % 4;
        base64 += '=' * padding;
      }
      final decoded = base64Decode(base64);
      return String.fromCharCodes(decoded);
    } catch (_) {
      return null;
    }
  }
  
  ProxyGroup? _parseGroupLine(String line) {
    try {
      final parts = line.split('=');
      if (parts.length < 2) return null;
      
      final name = parts[0].trim();
      final config = parts.sublist(1).join('=').trim();
      
      // Quantumult 组的格式: group_name = select, server1, server2
      final groupParts = config.split(',').map((s) => s.trim()).toList();
      if (groupParts.isEmpty) return null;
      
      final typeStr = groupParts[0].toLowerCase();
      GroupType type;
      
      switch (typeStr) {
        case 'select':
          type = GroupType.select;
          break;
        case 'url-test':
        case 'urltest':
          type = GroupType.urlTest;
          break;
        default:
          type = GroupType.select;
      }
      
      final proxies = groupParts.length > 1 ? groupParts.sublist(1) : <String>[];
      
      return ProxyGroup(
        name: name,
        type: type,
        proxies: proxies,
      );
    } catch (_) {
      return null;
    }
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.clash}) {
    final buffer = StringBuffer();
    
    buffer.writeln('[server_local]');
    for (final node in nodes) {
      buffer.writeln(_generateNodeLine(node));
    }
    buffer.writeln();
    
    buffer.writeln('[server_remote]');
    buffer.writeln();
    
    buffer.writeln('[server_group]');
    if (nodes.isNotEmpty) {
      final nodeNames = nodes.map((n) => n.remark).join(', ');
      buffer.writeln('AutoSelect = select, $nodeNames');
    }
    buffer.writeln();
    
    buffer.writeln('[filter_local]');
    buffer.writeln('geoip=cn, Direct');
    buffer.writeln();
    
    buffer.writeln('[rewrite_local]');
    buffer.writeln();
    
    buffer.writeln('[rule]');
    buffer.writeln('FINAL, AutoSelect');
    
    return buffer.toString();
  }
  
  String _generateNodeLine(ProxyNode node) {
    switch (node.type) {
      case ProxyType.vmess:
        final params = <String, String>{
          'server': node.server,
          'port': node.port.toString(),
          'protocol': 'vmess',
          'userId': node.userId ?? '',
          'aid': (node.alterId ?? 0).toString(),
          'network': node.network ?? 'tcp',
        };
        if (node.host != null) params['host'] = node.host!;
        if (node.path != null) params['path'] = node.path!;
        if (node.tlsSecure) params['tls'] = 'tls';
        if (node.sni != null) params['sni'] = node.sni!;
        
        final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
        return '${node.remark} = vmess://${_base64Encode(queryString)}';
        
      case ProxyType.ss:
        return '${node.remark} = ss://${_base64Encode('${node.server}:${node.port},${node.username},${node.password}')}';
        
      case ProxyType.ssr:
        final serverInfo = '${node.protocolParam ?? ''}:${node.obfsParam ?? ''}';
        final front = '${node.username}:${node.password}:${node.protocolParam ?? 'origin'}:${node.obfs ?? 'plain'}:${_base64Encode(serverInfo)}';
        return '${node.remark} = ssr://${_base64Encode(front)}@${node.server}:${node.port}';
        
      case ProxyType.trojan:
        return '${node.remark} = trojan://${node.password}@${node.server}:${node.port}';
        
      case ProxyType.vless:
        return '${node.remark} = vless://${node.userId}@${node.server}:${node.port}';
        
      default:
        return '# Unsupported: ${node.remark}';
    }
  }
  
  String _base64Encode(String input) {
    final bytes = input.codeUnits;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    
    int i = 0;
    while (i < bytes.length) {
      final b1 = bytes[i++];
      final b2 = i < bytes.length ? bytes[i++] : 0;
      final b3 = i < bytes.length ? bytes[i++] : 0;
      
      buffer.write(chars[(b1 >> 2) & 0x3F]);
      buffer.write(chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);
      buffer.write(i > bytes.length + 1 ? '=' : chars[((b2 << 2) | (b3 >> 6)) & 0x3F]);
      buffer.write(i > bytes.length ? '=' : chars[b3 & 0x3F]);
    }
    
    return buffer.toString();
  }
}
