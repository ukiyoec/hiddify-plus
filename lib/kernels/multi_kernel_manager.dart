import 'dart:async';
import 'package:hiddify/kernels/kernel_manager.dart';
import 'package:hiddify/kernel_updater/kernel_updater.dart';
import 'package:hiddify/kernels/singbox_kernel.dart';
import 'package:hiddify/kernels/clash_meta_kernel.dart';
import 'package:hiddify/kernels/v2ray_kernel.dart';

export 'package:hiddify/kernel_updater/kernel_updater.dart' show KernelType;

class MultiKernelManager implements IKernelManager {
  final Map<KernelType, IKernelManager> _kernels = {};
  IKernelManager? _activeKernelManager;
  KernelType? _activeKernelType;
  KernelStatus _status = KernelStatus.stopped;
  final _statusController = StreamController<KernelStatus>.broadcast();

  MultiKernelManager() {
    _kernels[KernelType.singBox] = SingBoxKernel();
    _kernels[KernelType.clashMeta] = ClashMetaKernel();
    _kernels[KernelType.v2ray] = V2RayKernel();
  }

  @override
  KernelInfo? get activeKernel => _activeKernelManager?.activeKernel;

  @override
  KernelType? get activeKernelType => _activeKernelType;

  @override
  KernelStatus get status => _status;

  @override
  Stream<KernelStatus> get statusStream => _statusController.stream;

  @override
  Future<KernelInfo> getKernelInfo(KernelType type) async {
    final kernel = _kernels[type];
    if (kernel == null) {
      throw KernelException('Unknown kernel type: $type');
    }
    return kernel.getKernelInfo(type);
  }

  List<KernelType> get availableKernelTypes => _kernels.keys.toList();

  @override
  Future<bool> switchKernel(KernelType type) async {
    final kernel = _kernels[type];
    if (kernel == null) {
      throw KernelException('Unknown kernel type: $type');
    }

    if (_activeKernelType == type) {
      return true;
    }

    if (_status == KernelStatus.running) {
      await stop();
    }

    _activeKernelManager = kernel;
    _activeKernelType = type;
    _activeKernelInfo = await kernel.getKernelInfo(type);

    return true;
  }

  KernelInfo? _activeKernelInfo;

  @override
  Future<bool> start(KernelConfig config) async {
    if (_activeKernelManager == null) {
      throw KernelException('No active kernel selected');
    }

    final kernel = _kernels[config.kernelType];
    if (kernel == null) {
      throw KernelException('Unknown kernel type: ${config.kernelType}');
    }

    if (_activeKernelType != config.kernelType) {
      await switchKernel(config.kernelType);
    }

    _status = KernelStatus.starting;
    _statusController.add(_status);

    try {
      final success = await kernel.start(config);
      if (success) {
        _status = KernelStatus.running;
      } else {
        _status = KernelStatus.error;
      }
      _statusController.add(_status);
      return success;
    } catch (e) {
      _status = KernelStatus.error;
      _statusController.add(_status);
      rethrow;
    }
  }

  @override
  Future<bool> stop() async {
    if (_activeKernelManager == null) {
      return true;
    }

    _status = KernelStatus.stopping;
    _statusController.add(_status);

    try {
      final success = await _activeKernelManager!.stop();
      _status = KernelStatus.stopped;
      _statusController.add(_status);
      return success;
    } catch (e) {
      _status = KernelStatus.error;
      _statusController.add(_status);
      rethrow;
    }
  }

  @override
  Future<bool> restart() async {
    await stop();
    if (_activeKernelInfo != null) {
      final config = KernelConfig(
        kernelType: _activeKernelType!,
        nodes: [],
      );
      return start(config);
    }
    return false;
  }

  @override
  Future<bool> downloadKernel(KernelType type, String url) async {
    final kernel = _kernels[type];
    if (kernel == null) {
      throw KernelException('Unknown kernel type: $type');
    }
    return kernel.downloadKernel(type, url);
  }

  @override
  Future<String?> getKernelVersion(KernelType type) async {
    final kernel = _kernels[type];
    if (kernel == null) {
      return null;
    }
    return kernel.getKernelVersion(type);
  }

  Future<Map<KernelType, KernelInfo>> getAllKernelInfo() async {
    final Map<KernelType, KernelInfo> result = {};
    for (final type in _kernels.keys) {
      result[type] = await getKernelInfo(type);
    }
    return result;
  }

  Future<KernelVersionInfo?> checkForUpdate(KernelType type) async {
    final updaterService = KernelUpdaterService();
    return updaterService.checkForUpdate(type);
  }

  Future<UpdateResult> downloadAndInstall(
    KernelType type,
    KernelVersionInfo versionInfo, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final updaterService = KernelUpdaterService();
    return updaterService.downloadAndInstall(
      type,
      versionInfo,
      onProgress: onProgress,
    );
  }

  void dispose() {
    _statusController.close();
    for (final kernel in _kernels.values) {
      if (kernel is SingBoxKernel) {
        kernel.dispose();
      } else if (kernel is ClashMetaKernel) {
        kernel.dispose();
      } else if (kernel is V2RayKernel) {
        kernel.dispose();
      }
    }
  }
}
