import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class SurgeParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.surge;
  
  @override
  bool canParse(String content) {
    final trimmed = content.trim();
    return trimmed.contains('[General]') && 
           (trimmed.contains('[Proxy]') || trimmed.contains('[proxy]'));
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid Surge format');
    }
    
    final lines = content.split('\n');
    final List<ProxyNode> nodes = [];
    final List<ProxyGroup> groups = [];
    
    String? currentSection;
    Map<String, String> currentGroup = {};
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      
      // 检测节头
      if (line.startsWith('[') && line.endsWith(']')) {
        // 保存上一个组的节点
        if (currentSection == 'Proxy Group' && currentGroup.isNotEmpty) {
          final group = _parseProxyGroup(currentGroup);
          if (group != null) groups.add(group);
        }
        
        currentSection = line.substring(1, line.length - 1);
        currentGroup = {};
        continue;
      }
      
      if (currentSection == 'Proxy') {
        final node = _parseProxyLine(line);
        if (node != null) nodes.add(node);
      } else if (currentSection == 'Proxy Group') {
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          currentGroup[key] = value;
        }
      }
    }
    
    // 保存最后一个组
    if (currentSection == 'Proxy Group' && currentGroup.isNotEmpty) {
      final group = _parseProxyGroup(currentGroup);
      if (group != null) groups.add(group);
    }
    
    return ParsedSubscription(
      nodes: nodes,
      groups: groups,
      format: SubscriptionFormat.surge,
    );
  }
  
  ProxyNode? _parseProxyLine(String line) {
    try {
      final parts = line.split('=');
      if (parts.length < 2) return null;
      
      final name = parts[0].trim();
      final config = parts.sublist(1).join('=').trim();
      
      // 解析配置: type, server, port, [username, password], [protocol, obfs, ...]
      final configParts = config.split(',').map((s) => s.trim()).toList();
      if (configParts.length < 3) return null;
      
      final type = configParts[0].toLowerCase();
      final server = configParts[1];
      final port = int.tryParse(configParts[2]) ?? 0;
      
      String? username;
      String? password;
      String? encryptMethod;
      String? protocol;
      String? obfs;
      String? obfsParam;
      
      switch (type) {
        case 'http':
        case 'https':
          if (configParts.length >= 5) {
            username = configParts[3];
            password = configParts[4];
          }
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.http,
            server: server,
            port: port,
            username: username,
            password: password,
          );
          
        case 'socks5':
          if (configParts.length >= 5) {
            username = configParts[3];
            password = configParts[4];
          }
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.socks5,
            server: server,
            port: port,
            username: username,
            password: password,
          );
          
        case 'ss':
          if (configParts.length >= 5) {
            encryptMethod = configParts[3];
            password = configParts[4];
          }
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.ss,
            server: server,
            port: port,
            username: encryptMethod,
            password: password,
          );
          
        case 'ssr':
          if (configParts.length >= 7) {
            protocol = configParts[3];
            obfs = configParts[4];
            encryptMethod = configParts[5];
            password = configParts[6];
            if (configParts.length > 7) {
              obfsParam = configParts.sublist(7).join(',');
            }
          }
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.ssr,
            server: server,
            port: port,
            username: encryptMethod ?? 'aes-256-cfb',
            password: password,
            protocolParam: protocol,
            obfs: obfs,
            obfsParam: obfsParam,
          );
          
        case 'vmess':
          // Surge 的 VMess 格式是 JSON
          if (configParts.length >= 2) {
            final vmessConfig = configParts.sublist(1).join(',');
            return _parseVmessConfig(name, vmessConfig);
          }
          return null;
          
        case 'vless':
          if (configParts.length >= 5) {
            password = configParts[3];
            encryptMethod = configParts[4]; // 实际是 flow
          }
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.vless,
            server: server,
            port: port,
            userId: password,
          );
          
        case 'trojan':
          if (configParts.length >= 4) {
            password = configParts[3];
          }
          return ProxyNode(
            id: _uuid.v4(),
            remark: name,
            type: ProxyType.trojan,
            server: server,
            port: port,
            password: password,
          );
          
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseVmessConfig(String name, String config) {
    try {
      // config 可能是 JSON 或者其他格式
      // 这里简化处理
      return ProxyNode(
        id: _uuid.v4(),
        remark: name,
        type: ProxyType.vmess,
        server: '',
        port: 0,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyGroup? _parseProxyGroup(Map<String, String> groupLines) {
    if (groupLines.isEmpty) return null;
    
    // Surge 组的格式: GroupName = select, Proxy1, Proxy2, ...
    // 或者: GroupName = url-test, Proxy1, http://test.com, 300, 300
    for (final entry in groupLines.entries) {
      final name = entry.key;
      final config = entry.value;
      
      final parts = config.split(',').map((s) => s.trim()).toList();
      if (parts.isEmpty) continue;
      
      final type = parts[0].toLowerCase();
      GroupType groupType;
      
      switch (type) {
        case 'select':
          groupType = GroupType.select;
          break;
        case 'url-test':
        case 'urltest':
          groupType = GroupType.urlTest;
          break;
        case 'fallback':
          groupType = GroupType.fallback;
          break;
        case 'load-balance':
        case 'loadbalance':
          groupType = GroupType.loadBalance;
          break;
        default:
          groupType = GroupType.select;
      }
      
      List<String> proxies = [];
      if (parts.length > 1) {
        // 跳过第一个元素（类型）
        if (groupType == GroupType.urlTest || groupType == GroupType.fallback || groupType == GroupType.loadBalance) {
          // 格式: url-test, Proxy1, http://xxx.com, 300, 300
          proxies = parts.sublist(1).where((p) => !p.startsWith('http')).toList();
        } else {
          proxies = parts.sublist(1);
        }
      }
      
      return ProxyGroup(
        name: name,
        type: groupType,
        proxies: proxies,
      );
    }
    
    return null;
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.clash}) {
    final buffer = StringBuffer();
    
    buffer.writeln('[General]');
    buffer.writeln('loglevel = notification');
    buffer.writeln('dns-server = 114.114.114.114, https://dns.google/dns-query');
    buffer.writeln('ipv6 = false');
    buffer.writeln();
    
    buffer.writeln('[Proxy]');
    for (final node in nodes) {
      buffer.writeln(_generateProxyLine(node));
    }
    buffer.writeln();
    
    buffer.writeln('[Proxy Group]');
    // 生成默认组
    if (nodes.isNotEmpty) {
      final nodeNames = nodes.map((n) => n.remark).join(', ');
      buffer.writeln('AutoSelect = select, $nodeNames');
    }
    buffer.writeln();
    
    buffer.writeln('[Rule]');
    buffer.writeln('DOMAIN-SUFFIX, google.com, AutoSelect');
    buffer.writeln('DOMAIN-KEYWORD, google, AutoSelect');
    buffer.writeln('DOMAIN, google.com, AutoSelect');
    buffer.writeln('GEOIP, CN, Direct');
    buffer.writeln('MATCH, AutoSelect');
    
    return buffer.toString();
  }
  
  String _generateProxyLine(ProxyNode node) {
    switch (node.type) {
      case ProxyType.http:
        var line = '${node.remark} = http, ${node.server}, ${node.port}';
        if (node.username != null && node.password != null) {
          line += ', ${node.username}, ${node.password}';
        }
        return line;
        
      case ProxyType.socks5:
        var line = '${node.remark} = socks5, ${node.server}, ${node.port}';
        if (node.username != null && node.password != null) {
          line += ', ${node.username}, ${node.password}';
        }
        return line;
        
      case ProxyType.ss:
        return '${node.remark} = ss, ${node.server}, ${node.port}, ${node.username ?? 'aes-256-cfb'}, ${node.password ?? ''}';
        
      case ProxyType.ssr:
        return '${node.remark} = ssr, ${node.server}, ${node.port}, ${node.protocolParam ?? 'origin'}, ${node.obfs ?? 'plain'}, ${node.username ?? 'aes-256-cfb'}, ${node.password ?? ''}';
        
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
        return '${node.remark} = vmess, ${node.server}, ${node.port}, username=${node.userId ?? ''}, tls=${node.tlsSecure}';
        
      case ProxyType.vless:
        var line = '${node.remark} = vless, ${node.server}, ${node.port}, username=${node.userId ?? ''}';
        if (node.tlsSecure) {
          line += ', tls';
        }
        return line;
        
      case ProxyType.trojan:
        return '${node.remark} = trojan, ${node.server}, ${node.port}, password=${node.password ?? ''}';
        
      default:
        return '# Unsupported type: ${node.type}';
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
