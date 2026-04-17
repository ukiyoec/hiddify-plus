import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'base/parser.dart';

class WireGuardParser implements IProxyParser {
  final _uuid = const Uuid();
  
  @override
  SubscriptionFormat get supportedFormat => SubscriptionFormat.wireguard;
  
  @override
  bool canParse(String content) {
    final trimmed = content.trim();
    return trimmed.contains('[Interface]') && trimmed.contains('[Peer]');
  }
  
  @override
  ParsedSubscription parse(String content) {
    if (!canParse(content)) {
      throw ParserParseException('Content is not valid WireGuard format');
    }
    
    final lines = content.split('\n');
    final List<ProxyNode> nodes = [];
    
    String? privateKey;
    String? address;
    String? dns;
    int? mtu;
    
    String? publicKey;
    String? presharedKey;
    String? endpoint;
    String? allowedIPs;
    int? listenPort;
    
    String? currentSection;
    int nodeCount = 0;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      
      if (line.startsWith('[') && line.endsWith(']')) {
        // 保存上一个节点
        if (currentSection == 'Peer' && endpoint != null) {
          nodeCount++;
          nodes.add(ProxyNode(
            id: _uuid.v4(),
            remark: 'WG-$nodeCount',
            type: ProxyType.wireguard,
            server: _extractHostFromEndpoint(endpoint),
            port: _extractPortFromEndpoint(endpoint) ?? 51820,
            privateKey: privateKey,
            publicKey: publicKey,
            preSharedKey: presharedKey,
            selfIp: address,
            dnsServers: dns != null ? [dns] : null,
            mtu: mtu,
            keepAlive: 25,
          ));
        }
        
        currentSection = line.substring(1, line.length - 1);
        
        // 重置 Peer 相关的值
        if (currentSection == 'Peer') {
          publicKey = null;
          presharedKey = null;
          endpoint = null;
          allowedIPs = null;
          listenPort = null;
        }
        continue;
      }
      
      if (currentSection == 'Interface') {
        final parts = line.split('=');
        if (parts.length < 2) continue;
        
        final key = parts[0].trim().toLowerCase();
        final value = parts.sublist(1).join('=').trim();
        
        switch (key) {
          case 'privatekey':
            privateKey = value;
            break;
          case 'address':
            address = value;
            break;
          case 'dns':
            dns = value.split(',').first.trim();
            break;
          case 'mtu':
            mtu = int.tryParse(value);
            break;
        }
      } else if (currentSection == 'Peer') {
        final parts = line.split('=');
        if (parts.length < 2) continue;
        
        final key = parts[0].trim().toLowerCase();
        final value = parts.sublist(1).join('=').trim();
        
        switch (key) {
          case 'publickey':
            publicKey = value;
            break;
          case 'presharedkey':
            presharedKey = value;
            break;
          case 'endpoint':
            endpoint = value;
            break;
          case 'allowedips':
            allowedIPs = value;
            break;
          case 'listenport':
            listenPort = int.tryParse(value);
            break;
        }
      }
    }
    
    // 保存最后一个节点
    if (endpoint != null) {
      nodeCount++;
      nodes.add(ProxyNode(
        id: _uuid.v4(),
        remark: 'WG-$nodeCount',
        type: ProxyType.wireguard,
        server: _extractHostFromEndpoint(endpoint),
        port: _extractPortFromEndpoint(endpoint) ?? 51820,
        privateKey: privateKey,
        publicKey: publicKey,
        preSharedKey: presharedKey,
        selfIp: address,
        dnsServers: dns != null ? [dns] : null,
        mtu: mtu,
        keepAlive: 25,
      ));
    }
    
    return ParsedSubscription(
      nodes: nodes,
      format: SubscriptionFormat.wireguard,
    );
  }
  
  String? _extractHostFromEndpoint(String endpoint) {
    // Endpoint 格式: host:port 或 [host]:port
    try {
      if (endpoint.startsWith('[')) {
        final endIndex = endpoint.lastIndexOf(']:');
        if (endIndex != -1) {
          return endpoint.substring(1, endIndex);
        }
      }
      
      final lastColon = endpoint.lastIndexOf(':');
      if (lastColon != -1) {
        return endpoint.substring(0, lastColon);
      }
      return endpoint;
    } catch (_) {
      return null;
    }
  }
  
  int? _extractPortFromEndpoint(String endpoint) {
    try {
      if (endpoint.startsWith('[')) {
        final endIndex = endpoint.lastIndexOf(']:');
        if (endIndex != -1) {
          return int.tryParse(endpoint.substring(endIndex + 2));
        }
      }
      
      final lastColon = endpoint.lastIndexOf(':');
      if (lastColon != -1) {
        return int.tryParse(endpoint.substring(lastColon + 1));
      }
      return 51820;
    } catch (_) {
      return 51820;
    }
  }
  
  @override
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.clash}) {
    final buffer = StringBuffer();
    
    for (final node in nodes) {
      buffer.writeln('[Interface]');
      if (node.privateKey != null) {
        buffer.writeln('PrivateKey = ${node.privateKey}');
      }
      if (node.selfIp != null) {
        buffer.writeln('Address = ${node.selfIp}');
      }
      if (node.dnsServers != null && node.dnsServers!.isNotEmpty) {
        buffer.writeln('DNS = ${node.dnsServers!.join(", ")}');
      }
      if (node.mtu != null) {
        buffer.writeln('MTU = ${node.mtu}');
      }
      buffer.writeln();
      
      buffer.writeln('[Peer]');
      if (node.publicKey != null) {
        buffer.writeln('PublicKey = ${node.publicKey}');
      }
      if (node.preSharedKey != null) {
        buffer.writeln('PresharedKey = ${node.preSharedKey}');
      }
      if (node.server != null && node.port != null) {
        buffer.writeln('Endpoint = ${node.server}:${node.port}');
      }
      buffer.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
      buffer.writeln('PersistentKeepalive = ${node.keepAlive ?? 25}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}
