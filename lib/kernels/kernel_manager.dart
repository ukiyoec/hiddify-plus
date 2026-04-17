import 'dart:async';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hiddify/kernel_updater/kernel_version_info.dart' show KernelType;
import 'package:hiddify/subscription_parser/models/models.dart';

export 'package:hiddify/kernel_updater/kernel_version_info.dart' show KernelType;

part 'kernel_manager.freezed.dart';

enum KernelStatus {
  stopped,
  starting,
  running,
  stopping,
  error;

  bool get isRunning => this == running;
  bool get isStopped => this == stopped;
}

@freezed
class KernelInfo with _$KernelInfo {
  const factory KernelInfo({
    required KernelType type,
    required String version,
    required KernelStatus status,
    String? downloadUrl,
    DateTime? lastUpdated,
  }) = _KernelInfo;
}

@freezed
class KernelConfig with _$KernelConfig {
  const factory KernelConfig({
    required KernelType kernelType,
    required List<ProxyNode> nodes,
    @Default([]) List<ProxyGroup> groups,
    Map<String, dynamic>? options,
  }) = _KernelConfig;
}

abstract class IKernelManager {
  Future<KernelInfo> getKernelInfo(KernelType type);
  KernelInfo? get activeKernel;
  KernelType? get activeKernelType;
  KernelStatus get status;
  
  Future<bool> switchKernel(KernelType type);
  Future<bool> start(KernelConfig config);
  Future<bool> stop();
  Future<bool> restart();
  
  Future<bool> downloadKernel(KernelType type, String url);
  Future<String?> getKernelVersion(KernelType type);
  
  Stream<KernelStatus> get statusStream;
}

class KernelException implements Exception {
  final String message;
  final KernelType? kernelType;
  final dynamic originalError;
  
  KernelException(this.message, {this.kernelType, this.originalError});
  
  @override
  String toString() => 'KernelException: $message';
}
