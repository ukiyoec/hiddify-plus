import '../../models/models.dart';

abstract class IProxyParser {
  SubscriptionFormat get supportedFormat;
  
  bool canParse(String content);
  
  ParsedSubscription parse(String content);
  
  String generate(List<ProxyNode> nodes, {SubscriptionFormat targetFormat = SubscriptionFormat.clash});
}

class ParserParseException implements Exception {
  final String message;
  final dynamic originalError;
  
  ParserParseException(this.message, [this.originalError]);
  
  @override
  String toString() => 'ParserParseException: $message';
}
