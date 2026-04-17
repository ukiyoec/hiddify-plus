import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class UriParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.vmess;
  
  @override
  bool canParse(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return false;
    
    final firstLine = lines.first.trim();
    return firstLine.startsWith('vmess://') ||
           firstLine.startsWith('vless://') ||
           firstLine.startsWith('trojan://') ||
           firstLine.startsWith('ss://') ||
           firstLine.startsWith('trojan-go://');
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid URI format');
    }
    
    final lines = content.split('\n');
    final List<ProxyNode> nodes = [];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      try {
        final node = _parseUri(trimmed);
        if (node != null) {
          nodes.add(node);
        }
      } catch (_) {
        // 跳过无效的 URI
      }
    }
    
    return ParsedSubscription(
      nodes: nodes,
      format: SubscriptionFormat.vmess,
    );
  }
  
  ProxyNode? _parseUri(String uri) {
    if (uri.startsWith('vmess://')) {
      return _parseVmess(uri);
    } else if (uri.startsWith('vless://')) {
      return _parseVless(uri);
    } else if (uri.startsWith('trojan://') || uri.startsWith('trojan-go://')) {
      return _parseTrojan(uri);
    } else if (uri.startsWith('ss://')) {
      return _parseSs(uri);
    }
    
    return null;
  }
  
  ProxyNode? _parseVmess(String uri) {
    try {
      final withoutScheme = uri.substring('vmess://'.length);
      final atIndex = withoutScheme.indexOf('@');
      
      String encoded;
      String? uriServer;
      int? uriPort;
      
      if (atIndex != -1) {
        encoded = withoutScheme.substring(0, atIndex);
        final serverPart = withoutScheme.substring(atIndex + 1);
        final colonIndex = serverPart.lastIndexOf(':');
        if (colonIndex != -1) {
          uriServer = serverPart.substring(0, colonIndex);
          uriPort = int.tryParse(serverPart.substring(colonIndex + 1));
        }
      } else {
        encoded = withoutScheme;
      }
      
      final decoded = utf8.decode(base64Decode(encoded), allowMalformed: true);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      
      final name = json['ps']?.toString() ?? 'VMess';
      final server = uriServer ?? json['add']?.toString() ?? '';
      final port = uriPort ?? int.tryParse(json['port']?.toString() ?? '') ?? 0;
      final userId = json['id']?.toString() ?? '';
      final alterId = int.tryParse(json['aid']?.toString() ?? '') ?? 0;
      final network = json['net']?.toString() ?? 'tcp';
      final host = json['host']?.toString();
      final path = json['path']?.toString();
      final tls = json['tls']?.toString();
      final sni = json['sni']?.toString();
      final fp = json['fp']?.toString();
      final alpn = json['alpn']?.toString();
      final edge = json['edge']?.toString();
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name,
        type: ProxyType.vmess,
        server: server,
        port: port,
        userId: userId,
        alterId: alterId,
        network: network,
        host: host,
        path: path,
        tlsSecure: tls == 'tls',
        sni: sni,
        fingerprint: fp,
        alpn: alpn,
        edge: edge,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseVless(String uri) {
    try {
      final withoutScheme = uri.substring('vless://'.length);
      final atIndex = withoutScheme.indexOf('@');
      if (atIndex == -1) return null;
      
      final userInfo = withoutScheme.substring(0, atIndex);
      final rest = withoutScheme.substring(atIndex + 1);
      
      final hashIndex = rest.indexOf('#');
      final questionIndex = rest.indexOf('?');
      final atSignIndex = rest.indexOf('@');
      
      final uuid = userInfo;
      String server;
      int port;
      String? name;
      Map<String, String> params = {};
      
      // 解析 server:port
      final serverPart = rest.substring(0, questionIndex != -1 ? questionIndex : (hashIndex != -1 ? hashIndex : rest.length));
      
      // 找到最后一个冒号，它前面是服务器，后面是端口
      final lastColonIndex = serverPart.lastIndexOf(':');
      if (lastColonIndex != -1) {
        server = serverPart.substring(0, lastColonIndex);
        port = int.tryParse(serverPart.substring(lastColonIndex + 1)) ?? 0;
      } else {
        return null;
      }
      
      // 解析查询参数
      if (questionIndex != -1) {
        final queryString = rest.substring(questionIndex + 1, hashIndex != -1 ? hashIndex : rest.length);
        for (final pair in queryString.split('&')) {
          final kv = pair.split('=');
          if (kv.length == 2) {
            params[kv[0]] = kv[1];
          }
        }
      }
      
      // 解析名称
      if (hashIndex != -1) {
        name = Uri.decodeComponent(rest.substring(hashIndex + 1));
      }
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'VLESS',
        type: ProxyType.vless,
        server: server,
        port: port,
        userId: uuid,
        host: params['host'],
        path: params['path'],
        network: params['type'] ?? 'tcp',
        tlsSecure: params['security'] == 'tls',
        sni: params['sni'],
        fingerprint: params['fp'],
        alpn: params['alpn'],
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseTrojan(String uri) {
    try {
      String cleaned = uri;
      if (cleaned.startsWith('trojan-go://')) {
        cleaned = cleaned.substring('trojan-go://'.length);
      } else {
        cleaned = cleaned.substring('trojan://'.length);
      }
      
      final atIndex = cleaned.indexOf('@');
      if (atIndex == -1) return null;
      
      final password = cleaned.substring(0, atIndex);
      final rest = cleaned.substring(atIndex + 1);
      
      final hashIndex = rest.indexOf('#');
      final questionIndex = rest.indexOf('?');
      
      String server;
      int port;
      String? name;
      Map<String, String> params = {};
      
      // 解析 server:port
      final serverPart = rest.substring(0, questionIndex != -1 ? questionIndex : (hashIndex != -1 ? hashIndex : rest.length));
      
      // 找到最后一个冒号，它前面是服务器，后面是端口
      final lastColonIndex = serverPart.lastIndexOf(':');
      if (lastColonIndex != -1) {
        server = serverPart.substring(0, lastColonIndex);
        port = int.tryParse(serverPart.substring(lastColonIndex + 1)) ?? 0;
      } else {
        return null;
      }
      
      // 解析查询参数
      if (questionIndex != -1) {
        final queryString = rest.substring(questionIndex + 1, hashIndex != -1 ? hashIndex : rest.length);
        for (final pair in queryString.split('&')) {
          final kv = pair.split('=');
          if (kv.length == 2) {
            params[kv[0]] = kv[1];
          }
        }
      }
      
      // 解析名称
      if (hashIndex != -1) {
        name = Uri.decodeComponent(rest.substring(hashIndex + 1));
      }
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'Trojan',
        type: uri.startsWith('trojan-go://') ? ProxyType.trojanGo : ProxyType.trojan,
        server: server,
        port: port,
        password: password,
        host: params['host'],
        path: params['path'],
        sni: params['sni'],
        fingerprint: params['fp'],
        alpn: params['alpn'],
        tlsSecure: true,
      );
    } catch (_) {
      return null;
    }
  }
  
  ProxyNode? _parseSs(String uri) {
    try {
      String cleaned = uri;
      if (cleaned.startsWith('ssconf://')) {
        cleaned = cleaned.substring('ssconf://'.length);
      } else {
        cleaned = cleaned.substring('ss://'.length);
      }
      
      final atIndex = cleaned.indexOf('@');
      if (atIndex == -1) return null;
      
      final userInfo = cleaned.substring(0, atIndex);
      final rest = cleaned.substring(atIndex + 1);
      
      final colonIndex = rest.lastIndexOf(':');
      final hashIndex = rest.indexOf('#');
      final questionIndex = rest.indexOf('?');
      
      String server;
      int port;
      String? name;
      String? plugin;
      String? pluginOpts;
      
      // 解码 userInfo
      String method, password;
      try {
        String base64Str = userInfo;
        // 添加 padding 如果需要
        if (userInfo.endsWith('=') || userInfo.endsWith('==')) {
          // 已经 padding 过了
        } else {
          base64Str = userInfo + '==';
        }
        final decoded = utf8.decode(base64Decode(base64Str));
        final colonIdx = decoded.indexOf(':');
        if (colonIdx != -1) {
          method = decoded.substring(0, colonIdx);
          password = decoded.substring(colonIdx + 1);
        } else {
          return null;
        }
      } catch (_) {
        return null;
      }
      
      if (colonIndex != -1) {
        server = rest.substring(0, colonIndex);
        String portAndRest = rest.substring(colonIndex + 1);
        
        // hashIndex 和 questionIndex 是相对于 rest 的，需要转换
        final hashIndexInRest = hashIndex;
        final questionIndexInRest = questionIndex;
        
        if (hashIndexInRest != -1) {
          final hashIndexInPortAndRest = hashIndexInRest - colonIndex - 1;
          port = int.tryParse(portAndRest.substring(0, hashIndexInPortAndRest)) ?? 0;
          name = Uri.decodeComponent(rest.substring(hashIndexInRest + 1));
        } else if (questionIndexInRest != -1) {
          final questionIndexInPortAndRest = questionIndexInRest - colonIndex - 1;
          port = int.tryParse(portAndRest.substring(0, questionIndexInPortAndRest)) ?? 0;
          name = Uri.decodeComponent(rest.substring(questionIndexInRest + 1));
        } else {
          port = int.tryParse(portAndRest) ?? 0;
        }
      } else {
        return null;
      }
      
      // 检测插件 (如 v2ray-plugin, obfs-local 等)
      if (questionIndex != -1) {
        final queryString = rest.substring(questionIndex + 1);
        if (queryString.contains('plugin=')) {
          for (final pair in queryString.split('&')) {
            final kv = pair.split('=');
            if (kv.length == 2 && kv[0] == 'plugin') {
              plugin = Uri.decodeComponent(kv[1]);
            }
          }
        }
      }
      
      return ProxyNode(
        id: _uuid.v4(),
        remark: name ?? 'Shadowsocks',
        type: ProxyType.ss,
        server: server,
        port: port,
        username: method,
        password: password,
        plugin: plugin,
        pluginOptions: pluginOpts,
        tlsSecure: plugin?.contains('tls') ?? false,
      );
    } catch (_) {
      return null;
    }
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.clash}) {
    final buffer = StringBuffer();
    
    for (final node in nodes) {
      String uri;
      
      switch (node.type) {
        case ProxyType.vmess:
          uri = _generateVmess(node);
          break;
        case ProxyType.vless:
          uri = _generateVless(node);
          break;
        case ProxyType.trojan:
        case ProxyType.trojanGo:
          uri = _generateTrojan(node);
          break;
        case ProxyType.ss:
          uri = _generateSs(node);
          break;
        default:
          uri = '# Unsupported type: ${node.type}';
      }
      
      buffer.writeln(uri);
    }
    
    return buffer.toString();
  }
  
  String _generateVmess(ProxyNode node) {
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
      'sni': node.sni ?? '',
      'fp': node.fingerprint ?? '',
    };
    
    final encoded = base64Encode(utf8.encode(jsonEncode(json)));
    return 'vmess://$encoded';
  }
  
  String _generateVless(ProxyNode node) {
    var url = 'vless://${node.userId ?? ''}@${node.server}:${node.port}';
    
    final params = <String, String>{};
    if (node.host != null) params['host'] = node.host!;
    if (node.path != null) params['path'] = node.path!;
    if (node.network != null) params['type'] = node.network!;
    if (node.tlsSecure) params['security'] = 'tls';
    if (node.sni != null) params['sni'] = node.sni!;
    if (node.fingerprint != null) params['fp'] = node.fingerprint!;
    if (node.alpn != null) params['alpn'] = node.alpn!;
    
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    
    url += '#${Uri.encodeComponent(node.remark)}';
    return url;
  }
  
  String _generateTrojan(ProxyNode node) {
    var url = 'trojan://${node.password ?? ''}@${node.server}:${node.port}';
    
    final params = <String, String>{};
    if (node.host != null) params['host'] = node.host!;
    if (node.path != null) params['path'] = node.path!;
    if (node.sni != null) params['sni'] = node.sni!;
    if (node.fingerprint != null) params['fp'] = node.fingerprint!;
    if (node.alpn != null) params['alpn'] = node.alpn!;
    
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    
    url += '#${Uri.encodeComponent(node.remark)}';
    return url;
  }
  
  String _generateSs(ProxyNode node) {
    final userInfo = base64Encode(utf8.encode('${node.username ?? ""}:${node.password ?? ""}'));
    var url = 'ss://$userInfo@${node.server}:${node.port}';
    
    if (node.plugin != null) {
      url += '?plugin=${Uri.encodeComponent(node.plugin!)}';
      if (node.pluginOptions != null) {
        url += ';${Uri.encodeComponent(node.pluginOptions!)}';
      }
    }
    
    url += '#${Uri.encodeComponent(node.remark)}';
    return url;
  }
}
