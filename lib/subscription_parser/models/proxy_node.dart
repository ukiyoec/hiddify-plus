import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'proxy_node.freezed.dart';
part 'proxy_node.g.dart';

enum ProxyType {
  // Shadowsocks
  ss,
  ss2022,
  ssr,
  
  // VMess
  vmess,
  
  // VLESS
  vless,
  
  // Trojan
  trojan,
  trojanGo,
  
  // Hysteria
  hysteria,
  hysteria2,
  
  // TUIC
  tuic,
  
  // WireGuard
  wireguard,
  
  // SOCKS
  socks5,
  http,
  
  // SSH
  ssh,
  
  // Others
  naive,
  shadowtls,
  mieru,
  
  // Sing-box specific
  direct,
  block,
  dns,
  selector,
  urltest,
  balancer,
  warp,
  
  unknown;

  String get key => name;
  
  static ProxyType fromString(String type) {
    final lower = type.toLowerCase();
    
    // 映射 sing-box 类型名称
    const typeMapping = {
      'shadowsocks': 'ss',
      'shadowsocksr': 'ssr',
      'vmess': 'vmess',
      'vless': 'vless',
      'trojan': 'trojan',
      'hysteria': 'hysteria',
      'hysteria2': 'hysteria2',
      'tuic': 'tuic',
      'wireguard': 'wireguard',
      'socks': 'socks5',
      'http': 'http',
      'ssh': 'ssh',
      'naive': 'naive',
      'shadowtls': 'shadowtls',
      'mieru': 'mieru',
      'direct': 'direct',
      'block': 'block',
      'dns': 'dns',
      'selector': 'selector',
      'urltest': 'urltest',
      'balancer': 'balancer',
      'warp': 'warp',
    };
    
    final mappedType = typeMapping[lower] ?? lower;
    
    return ProxyType.values.firstWhere(
      (e) => e.key == mappedType,
      orElse: () => ProxyType.unknown,
    );
  }
}

@freezed
class ProxyNode with _$ProxyNode {
  const ProxyNode._();

  const factory ProxyNode({
    required String id,
    required String remark,
    required ProxyType type,
    required String server,
    required int port,
    
    // Optional auth
    String? username,
    String? password,
    
    // VMess specific
    String? userId,
    int? alterId,
    String? encryptMethod,
    
    // Network
    String? network,
    String? transport,
    String? host,
    String? path,
    String? edge,
    
    // TLS
    @Default(false) bool tlsSecure,
    String? sni,
    String? fingerprint,
    String? alpn,
    String? ca,
    
    // Obfs
    String? obfs,
    String? obfsParam,
    
    // Protocol specific
    String? protocolParam,
    
    // Plugin (for Clash/Singbox)
    String? plugin,
    String? pluginOptions,
    
    // Hysteria
    String? upSpeed,
    String? downSpeed,
    
    // TUIC
    String? uuid,
    
    // WireGuard
    String? privateKey,
    String? publicKey,
    String? preSharedKey,
    String? selfIp,
    List<String>? dnsServers,
    int? mtu,
    int? keepAlive,
    
    // SSH
    String? privateKeyPath,
    String? publicKeyPath,
    
    // Underlying proxy (for proxy chains)
    String? underlyingProxy,
    
    // State
    int? latency,
    @Default(false) bool isActive,
    DateTime? lastChecked,
  }) = _ProxyNode;

  factory ProxyNode.fromJson(Map<String, dynamic> json) =>
      _$ProxyNodeFromJson(json);
  
  String get identifier => '$remark-$server:$port';
}

@freezed
class ProxyGroup with _$ProxyGroup {
  const ProxyGroup._();

  const factory ProxyGroup({
    required String name,
    required GroupType type,
    @Default([]) List<String> proxies,
    String? url,
    @Default(300) int interval,
    @Default(5) int timeout,
    @Default(150) int tolerance,
    @Default(true) bool lazy,
    @Default(false) bool disableUdp,
  }) = _ProxyGroup;

  factory ProxyGroup.fromJson(Map<String, dynamic> json) =>
      _$ProxyGroupFromJson(json);
}

enum GroupType {
  select,
  urlTest,
  fallback,
  loadBalance,
  relay;

  String get key => name;

  String toClashString() => switch (this) {
    select => 'select',
    urlTest => 'url-test',
    fallback => 'fallback',
    loadBalance => 'load-balance',
    relay => 'relay',
  };

  static GroupType fromString(String type) {
    final lower = type.toLowerCase();
    
    // 映射 Clash 格式的带连字符的字符串
    const typeMapping = {
      'select': 'select',
      'url-test': 'urlTest',
      'url_test': 'urlTest',
      'fallback': 'fallback',
      'load-balance': 'loadBalance',
      'load_balance': 'loadBalance',
      'relay': 'relay',
    };
    
    final mappedType = typeMapping[lower] ?? lower;
    
    return GroupType.values.firstWhere(
      (e) => e.key == mappedType || e.name == mappedType,
      orElse: () => GroupType.select,
    );
  }
}
