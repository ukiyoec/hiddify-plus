import '../models/models.dart';
import 'base/parser.dart';
import 'clash_parser.dart';
import 'singbox_parser.dart';
import 'uri_parser.dart';
import 'v2ray_parser.dart';
import 'format_detector.dart';

class ParserFactory {
  static final Map<SubscriptionFormat, IProxyParser> _parsers = {
    SubscriptionFormat.clash: ClashParser(),
    SubscriptionFormat.clashMeta: ClashParser(), // 使用同一个解析器
    SubscriptionFormat.singbox: SingBoxParser(),
    SubscriptionFormat.v2ray: V2RayParser(),
    SubscriptionFormat.vmess: UriParser(), // URI 解析器处理
    SubscriptionFormat.vless: UriParser(),
    SubscriptionFormat.trojan: UriParser(),
    SubscriptionFormat.ss: UriParser(),
    SubscriptionFormat.ssr: UriParser(),
  };
  
  static IProxyParser getParser(SubscriptionFormat format) {
    final parser = _parsers[format];
    if (parser != null) return parser;
    
    throw ParserParseException('No parser available for format: $format');
  }
  
  static ParsedSubscription parse(String content) {
    // 1. 检测格式
    final format = FormatDetector.detect(content);
    
    // 2. 获取对应 Parser
    final parser = getParser(format);
    
    // 3. 解析
    return parser.parse(content);
  }
  
  static ParsedSubscription parseWithFormat(String content, SubscriptionFormat format) {
    final parser = getParser(format);
    return parser.parse(content);
  }
  
  static String generate(
    List<ProxyNode> nodes, {
    SubscriptionFormat targetFormat = SubscriptionFormat.clash,
  }) {
    final parser = getParser(targetFormat);
    return parser.generate(nodes, targetFormat: targetFormat);
  }
  
  static SubscriptionFormat detectFormat(String content) {
    return FormatDetector.detect(content);
  }
  
  static bool isValidFormat(String content) {
    final format = FormatDetector.detect(content);
    return format != SubscriptionFormat.unknown;
  }
  
  static List<SubscriptionFormat> get supportedFormats => _parsers.keys.toList();
}
