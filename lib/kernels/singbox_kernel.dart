import 'dart:async';
import 'dart:io';
import 'package:hiddify/kernels/kernel_manager.dart';
import 'package:hiddify/kernels/config_generator/singbox_config_generator.dart';
import 'package:hiddify/kernel_updater/kernel_updater.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class SingBoxKernel implements IKernelManager {
  KernelInfo? _activeKernel;
  KernelStatus _status = KernelStatus.stopped;
  final _statusController = StreamController<KernelStatus>.broadcast();
  final _updaterService = KernelUpdaterService();
  String? _configPath;

  @override
  KernelInfo? get activeKernel => _activeKernel;

  @override
  KernelType? get activeKernelType => _activeKernel?.type;

  @override
  KernelStatus get status => _status;

  @override
  Stream<KernelStatus> get statusStream => _statusController.stream;

  @override
  Future<KernelInfo> getKernelInfo(KernelType type) async {
    final localInfo = await _updaterService.getLocalInfo(type);
    return KernelInfo(
      type: type,
      version: localInfo?.version ?? 'unknown',
      status: _status,
      downloadUrl: _getDownloadUrl(type),
    );
  }

  String _getDownloadUrl(KernelType type) {
    final platform = Platform.operatingSystem.toLowerCase();
    final arch = Platform.localHostname.contains('arm64') ||
            Platform.localHostname.contains('aarch64')
        ? 'arm64'
        : 'amd64';
    final ext = platform == 'windows' ? '.exe' : '';
    return 'https://github.com/SagerNet/sing-box/releases/download/'
        'v1.8.0/sing-box-1.8.0-$platform-$arch$ext';
  }

  @override
  Future<bool> switchKernel(KernelType type) async {
    if (type != KernelType.singBox) {
      throw KernelException('SingBox kernel can only switch to singBox type');
    }
    _activeKernel = await getKernelInfo(type);
    return true;
  }

  @override
  Future<bool> start(KernelConfig config) async {
    if (config.kernelType != KernelType.singBox) {
      throw KernelException(
        'Invalid config type for SingBox kernel',
        kernelType: config.kernelType,
      );
    }

    _status = KernelStatus.starting;
    _statusController.add(_status);

    try {
      final configMap = SingBoxConfigGenerator.generateConfig(
        nodes: config.nodes,
        groups: config.groups,
      );
      final configString = SingBoxConfigGenerator.toJsonString(configMap);

      _configPath = await _saveConfig(configString);

      final localInfo = await _updaterService.getLocalInfo(KernelType.singBox);
      if (localInfo == null) {
        throw KernelException('sing-box kernel not installed');
      }

      final executable = localInfo.installedPath;
      final executableFile = File(executable);

      if (!await executableFile.exists()) {
        throw KernelException('sing-box executable not found at: $executable');
      }

      _status = KernelStatus.running;
      _statusController.add(_status);
      return true;
    } catch (e) {
      _status = KernelStatus.error;
      _statusController.add(_status);
      rethrow;
    }
  }

  Future<String> _saveConfig(String configContent) async {
    final dir = await getApplicationSupportDirectory();
    final configDir = Directory(path.join(dir.path, 'singbox'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    final configFile = File(path.join(configDir.path, 'config.json'));
    await configFile.writeAsString(configContent);
    return configFile.path;
  }

  @override
  Future<bool> stop() async {
    _status = KernelStatus.stopping;
    _statusController.add(_status);

    if (_configPath != null) {
      final configFile = File(_configPath!);
      if (await configFile.exists()) {
        await configFile.delete();
      }
      _configPath = null;
    }

    _status = KernelStatus.stopped;
    _statusController.add(_status);
    return true;
  }

  @override
  Future<bool> restart() async {
    await stop();
    if (_activeKernel != null) {
      final config = KernelConfig(
        kernelType: KernelType.singBox,
        nodes: [],
      );
      return start(config);
    }
    return false;
  }

  @override
  Future<bool> downloadKernel(KernelType type, String url) async {
    if (type != KernelType.singBox) {
      throw KernelException('Invalid kernel type for SingBox download');
    }

    final versionInfo = KernelVersionInfo(
      type: type,
      version: '1.8.0',
      downloadUrl: url,
      sha256: '',
      fileSize: 0,
      releaseDate: DateTime.now(),
    );

    final result = await _updaterService.downloadAndInstall(
      type,
      versionInfo,
    );

    return result.success;
  }

  @override
  Future<String?> getKernelVersion(KernelType type) async {
    if (type != KernelType.singBox) return null;
    final localInfo = await _updaterService.getLocalInfo(type);
    return localInfo?.version;
  }

  Future<KernelVersionInfo?> checkForUpdate() async {
    return _updaterService.checkForUpdate(KernelType.singBox);
  }

  Future<UpdateResult> downloadAndInstall(
    KernelVersionInfo versionInfo, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    return _updaterService.downloadAndInstall(
      KernelType.singBox,
      versionInfo,
      onProgress: onProgress,
    );
  }

  Future<bool> rollback() async {
    return _updaterService.rollback(KernelType.singBox);
  }

  void dispose() {
    _statusController.close();
  }
}
