import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'proxy_node.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

enum SubscriptionFormat {
  unknown,
  
  // Clash 系列
  clash,
  clashMeta,
  
  // sing-box
  singbox,
  
  // V2Ray 系列
  v2ray,
  
  // URI 格式 (仅作为来源)
  vmess,
  vless,
  trojan,
  ss,
  ssr,
  
  // 其他格式
  surge,
  quan,
  quanx,
  loon,
  ssd,
  surfboard;

  String get key => name;

  bool get isYaml => this == clash || this == clashMeta;
  bool get isJson => this == singbox || this == v2ray;
  
  static SubscriptionFormat fromString(String format) {
    final lower = format.toLowerCase();
    return SubscriptionFormat.values.firstWhere(
      (e) => e.key == lower,
      orElse: () => SubscriptionFormat.unknown,
    );
  }
}

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const SubscriptionInfo._();

  const factory SubscriptionInfo({
    required int upload,
    required int download,
    required int total,
    required DateTime expire,
    String? webPageUrl,
    String? supportUrl,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.empty() => SubscriptionInfo(
        upload: 0,
        download: 0,
        total: 0,
        expire: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isExpired => expire.isBefore(DateTime.now());
  
  int get consumption => upload + download;
  int get remainingBw => total - consumption;
  double get remainingBwRatio => 
      total > 0 ? (remainingBw / total).clamp(0, 1) : 0;
}

@freezed
class Subscription with _$Subscription {
  const Subscription._();

  const factory Subscription({
    required String id,
    required String name,
    required String url,
    required SubscriptionFormat format,
    @Default([]) List<ProxyNode> nodes,
    @Default([]) List<ProxyGroup> groups,
    DateTime? lastUpdate,
    SubscriptionInfo? info,
    String? rawContent,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}

@freezed
class ParsedSubscription with _$ParsedSubscription {
  const ParsedSubscription._();

  const factory ParsedSubscription({
    required List<ProxyNode> nodes,
    @Default([]) List<ProxyGroup> groups,
    SubscriptionInfo? info,
    String? name,
    @Default(SubscriptionFormat.unknown) SubscriptionFormat format,
  }) = _ParsedSubscription;

  factory ParsedSubscription.fromJson(Map<String, dynamic> json) =>
      _$ParsedSubscriptionFromJson(json);
}
