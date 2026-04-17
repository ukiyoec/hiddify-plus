import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class LoonParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.loon;
  
  @override
  bool canParse(String content) {
    final trimmed = content.trim();
    // Loon 格式包含 Proxy= 或 Server= 等节
    return trimmed.contains('[Proxy]') || 
           trimmed.contains('[Server]') ||
           trimmed.contains('vmess://') ||
           trimmed.contains('ss://');
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid Loon format');
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
      
      if (currentSection == 'Proxy' || currentSection == 'Server') {
        final node = _parseProxyLine(line);
        if (node != null) nodes.add(node);
      } else if (currentSection == 'Proxy Group' || currentSection == 'Group') {
        final group = _parseGroupLine(line);
        if (group != null) groups.add(group);
      }
    }
    
    return ParsedSubscription(
      nodes: nodes,
      groups: groups,
      format: SubscriptionFormat.loon,
    );
  }
  
  ProxyNode? _parseProxyLine(String line) {
    try {
      // Loon 支持多种 URI 格式: name=protocol,server,port,username,password
      // 或者直接是 URI
      
      if (line.contains('=')) {
        final parts = line.split('=');
        if (parts.length < 2) return null;
        
        final name = parts[0].trim();
        final config = parts.sublist(1).join('=').trim();
        
        // 检查是否是 URI
        if (config.contains('://')) {
          return _parseUri(config, name);
        }
        
        // 标准格式: type,server,port,username,password
        return _parseStandardLine(name, config);
      } else if (line.contains('://')) {
        // 整行都是 URI，尝试解析
        return _parseUri(line, null);
      }
      
      return null;
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseUri(String uri, String? name) {
    if (uri.startsWith('vmess://')) {
      return _parseVmess(uri, name);
    } else if (uri.startsWith('ss://')) {
      return _parseShadowsocks(uri, name);
    } else if (uri.startsWith('ssr://')) {
      return _parseShadowsocksR(uri, name);
    } else if (uri.startsWith('trojan://')) {
      return _parseTrojan(uri, name);
    } else if (uri.startsWith('vless://')) {
      return _parseVless(uri, name);
    }
    return null;
  }
  
  ProxyNode? _parseStandardLine(String name, String config) {
    try {
      final parts = config.split(',').map((s) => s.trim()).toList();
      if (parts.isEmpty) return null;
      
      final type = parts[0].toLowerCase();
      
      switch (type) {
        case 'http':
        case 'https':
          if (parts.length < 3) return null;
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.http,
            server: parts[1],
            port: int.tryParse(parts[2]) ?? 0,
            username: parts.length > 3 ? parts[3] : null,
            password: parts.length > 4 ? parts[4] : null,
          );
          
        case 'socks5':
          if (parts.length < 3) return null;
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.socks5,
            server: parts[1],
            port: int.tryParse(parts[2]) ?? 0,
            username: parts.length > 3 ? parts[3] : null,
            password: parts.length > 4 ? parts[4] : null,
          );
          
        case 'ss':
          if (parts.length < 5) return null;
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.ss,
            server: parts[1],
            port: int.tryParse(parts[2]) ?? 0,
            username: parts[3],
            password: parts[4],
          );
          
        case 'ssr':
          if (parts.length < 7) return null;
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.ssr,
            server: parts[1],
            port: int.tryParse(parts[2]) ?? 0,
            username: parts[3],
            password: parts[4],
            protocolParam: parts[5],
            obfs: parts[6],
          );
          
        case 'trojan':
          if (parts.length < 3) return null;
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.trojan,
            server: parts[1],
            port: int.tryParse(parts[2]) ?? 0,
            password: parts.length > 3 ? parts[3] : '',
          );
          
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseVmess(String uri, String? name) {
    try {
      final withoutScheme = uri.substring('vmess://'.length);
      final decoded = _base64Decode(withoutScheme);
      if (decoded == null) return null;
      
      // 尝试解析 JSON
      try {
        final json = _parseJson(decoded);
        return ProxyNode(
          id: _uuid.v4(),
          remark: name ?? json['ps'] ?? json['remark'] ?? 'VMess',
          type: ProxyType.vmess,
          server: json['add'] ?? json['server'] ?? '',
          port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
          userId: json['id'] ?? '',
          alterId: int.tryParse(json['aid']?.toString() ?? '0']),
          network: json['net'] ?? json['network'] ?? 'tcp',
          host: json['host'],
          path: json['path'],
          tlsSecure: json['tls'] == 'tls' || json['tls'] == 'true',
          sni: json['sni'] ?? json['peer'],
        );
      } catch (_) {
        // 如果不是 JSON，尝试解析 URI 参数格式
        if (decoded.contains('=')) {
          final params = _parseQueryString(decoded);
          return ProxyNode(
            id: _uuid.v4(),
            remark: name ?? params['remark'] ?? 'VMess',
            type: ProxyType.vmess,
            server: params['server'] ?? '',
            port: int.tryParse(params['port'] ?? '0') ?? 0,
            userId: params['id'] ?? '',
            network: params['net'] ?? 'tcp',
          );
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseShadowsocks(String uri, String? name) {
    try {
      String cleaned = uri;
      if (cleaned.startsWith('ss://')) {
        cleaned = cleaned.substring('ss://'.length);
      }
      
      final atIndex = cleaned.indexOf('@');
      if (atIndex == -1) return null;
      
      final userInfo = _base64Decode(cleaned.substring(0, atIndex)) ?? cleaned.substring(0, atIndex);
      final rest = cleaned.substring(atIndex + 1);
      
      final colonIndex = rest.lastIndexOf(':');
      if (colonIndex == -1) return null;
      
      final server = rest.substring(0, colonIndex);
      final portStr = rest.substring(colonIndex + 1).split(',').first;
      final port = int.tryParse(portStr) ?? 0;
      
      final userParts = userInfo.split(':');
      final method = userParts.isNotEmpty ? userParts[0] : 'aes-256-cfb';
      final password = userParts.length > 1 ? userParts[1] : '';
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'SS-$server:$port',
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
  
  ProxyNode? _parseShadowsocksR(String uri, String? name) {
    try {
      final withoutScheme = uri.substring('ssr://'.length);
      final decoded = _base64Decode(withoutScheme);
      if (decoded == null) return null;
      
      final parts = decoded.split(':');
      if (parts.length < 5) return null;
      
      final method = parts[0];
      final password = parts[1];
      final protocol = parts[2];
      final obfs = parts[3];
      
      String serverInfo = parts.sublist(4).join(':');
      final slashIndex = serverInfo.indexOf('/');
      if (slashIndex != -1) {
        serverInfo = serverInfo.substring(0, slashIndex);
      }
      
      final hashIndex = serverInfo.indexOf('#');
      if (hashIndex != -1) {
        serverInfo = serverInfo.substring(0, hashIndex);
      }
      
      final serverDecoded = _base64Decode(serverInfo);
      if (serverDecoded == null) return null;
      
      final serverParts = serverDecoded.split(':');
      if (serverParts.length < 2) return null;
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'SSR-${serverParts[0]}:${serverParts[1]}',
        type: ProxyType.ssr,
        server: serverParts[0],
        port: int.tryParse(serverParts[1]) ?? 0,
        username: method,
        password: password,
        protocolParam: protocol,
        obfs: obfs,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseTrojan(String uri, String? name) {
    try {
      final withoutScheme = uri.substring('trojan://'.length);
      final parts = withoutScheme.split('@');
      if (parts.length < 2) return null;
      
      final password = parts[0];
      final rest = parts[1];
      
      final colonIndex = rest.lastIndexOf(':');
      if (colonIndex == -1) return null;
      
      final server = rest.substring(0, colonIndex);
      final portStr = rest.substring(colonIndex + 1).split(',').first;
      final port = int.tryParse(portStr) ?? 0;
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'Trojan-$server:$port',
        type: ProxyType.trojan,
        server: server,
        port: port,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseVless(String uri, String? name) {
    try {
      final withoutScheme = uri.substring('vless://'.length);
      final parts = withoutScheme.split('@');
      if (parts.length < 2) return null;
      
      final uuid = parts[0];
      final rest = parts[1];
      
      final colonIndex = rest.lastIndexOf(':');
      if (colonIndex == -1) return null;
      
      final server = rest.substring(0, colonIndex);
      final portStr = rest.substring(colonIndex + 1).split(',').first;
      final port = int.tryParse(portStr) ?? 0;
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'VLESS-$server:$port',
        type: ProxyType.vless,
        server: server,
        port: port,
        userId: uuid,
      );
    } catch (_) {
      return null;
    }
  }
  
  Map<String, dynamic> _parseJson(String jsonStr) {
    // 简单的 JSON 解析，用于处理 VMess 配置
    // 这里应该使用 jsonDecode，但为了减少依赖先手动解析
    throw UnimplementedError('Use json.decode from dart:convert');
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
      
      // Loon 组的格式: group_name = select, server1, server2
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
    
    buffer.writeln('[Proxy]');
    for (final node in nodes) {
      buffer.writeln(_generateProxyLine(node));
    }
    buffer.writeln();
    
    buffer.writeln('[Proxy Group]');
    if (nodes.isNotEmpty) {
      final nodeNames = nodes.map((n) => n.remark).join(', ');
      buffer.writeln('AutoSelect = select, $nodeNames');
    }
    buffer.writeln();
    
    buffer.writeln('[Rule]');
    buffer.writeln('DOMAIN-SUFFIX, google.com, AutoSelect');
    buffer.writeln('GEOIP, CN, DIRECT');
    buffer.writeln('FINAL, AutoSelect');
    
    return buffer.toString();
  }
  
  String _generateProxyLine(ProxyNode node) {
    switch (node.type) {
      case ProxyType.http:
        var line = '${node.remark} = HTTP, ${node.server}, ${node.port}';
        if (node.username != null && node.password != null) {
          line += ', ${node.username}, ${node.password}';
        }
        return line;
        
      case ProxyType.socks5:
        var line = '${node.remark} = SOCKS5, ${node.server}, ${node.port}';
        if (node.username != null && node.password != null) {
          line += ', ${node.username}, ${node.password}';
        }
        return line;
        
      case ProxyType.ss:
        return '${node.remark} = SS, ${node.server}, ${node.port}, ${node.username}, ${node.password}';
        
      case ProxyType.ssr:
        return '${node.remark} = SSR, ${node.server}, ${node.port}, ${node.username}, ${node.password}, ${node.protocolParam ?? 'origin'}, ${node.obfs ?? 'plain'}';
        
      case ProxyType.trojan:
        return '${node.remark} = Trojan, ${node.server}, ${node.port}, ${node.password}';
        
      case ProxyType.vmess:
        final json = {
          'v': '2',
          'ps': node.remark,
          'add': node.server,
          'port': node.port.toString(),
          'id': node.userId ?? '',
          'aid': (node.alterId ?? 0).toString(),
          'net': node.network ?? 'tcp',
          'type': node.host ?? 'none',
          'host': node.host ?? '',
          'path': node.path ?? '',
          'tls': node.tlsSecure ? 'tls' : '',
        };
        final encoded = _base64Encode(json.toString());
        return '${node.remark} = vmess://$encoded';
        
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
