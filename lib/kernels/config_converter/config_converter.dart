import 'package:hiddify/kernel_updater/kernel_version_info.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:hiddify/subscription_parser/services/converter.dart';

export 'package:hiddify/kernel_updater/kernel_version_info.dart' show KernelType;
export 'package:hiddify/subscription_parser/models/models.dart' show ProxyNode, ProxyGroup, ProxyType, SubscriptionFormat;

class ConfigConverter {
  static final ConfigConverter _instance = ConfigConverter._internal();
  factory ConfigConverter() => _instance;
  ConfigConverter._internal();

  final _subscriptionConverter = SubscriptionConverter();

  String convertContent({
    required String content,
    required KernelType targetKernel,
    bool decodeBase64 = true,
  }) {
    return _subscriptionConverter.convertToKernel(
      content,
      targetKernel: targetKernel,
      decodeBase64: decodeBase64,
    );
  }

  List<ProxyNode> parseNodes(String content, {bool decodeBase64 = true}) {
    return _subscriptionConverter.parseOnly(content, decodeBase64: decodeBase64);
  }

  String generateConfig({
    required List<ProxyNode> nodes,
    required KernelType targetKernel,
    List<ProxyGroup>? groups,
  }) {
    return _subscriptionConverter.nodesToKernel(
      nodes,
      targetKernel: targetKernel,
      groups: groups,
    );
  }

  String convertNodesToFormat({
    required List<ProxyNode> nodes,
    required KernelType targetKernel,
    List<ProxyGroup>? groups,
  }) {
    return generateConfig(
      nodes: nodes,
      targetKernel: targetKernel,
      groups: groups,
    );
  }

  List<ProxyNode> mergeNodes(List<String> contents, {bool decodeBase64 = true}) {
    return _subscriptionConverter.mergeSubscriptions(
      contents,
      decodeBase64: decodeBase64,
    );
  }

  Map<String, List<ProxyNode>> splitByProtocol(List<ProxyNode> nodes) {
    return _subscriptionConverter.splitByProtocol(nodes);
  }

  List<ProxyNode> filterByProtocol(
    List<ProxyNode> nodes,
    Set<ProxyType> allowedTypes,
  ) {
    return _subscriptionConverter.filterByProtocol(nodes, allowedTypes);
  }

  List<ProxyNode> filterByName(List<ProxyNode> nodes, String keyword) {
    return _subscriptionConverter.filterByName(nodes, keyword);
  }

  SubscriptionFormat detectFormat(String content) {
    return _subscriptionConverter.detectInputFormat(content);
  }

  List<ProxyGroup> generateDefaultGroups(List<ProxyNode> nodes) {
    return _subscriptionConverter.generateDefaultGroups(nodes);
  }
}
