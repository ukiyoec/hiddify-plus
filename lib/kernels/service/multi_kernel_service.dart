import 'dart:async';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/kernels/kernel_manager.dart';
import 'package:hiddify/kernels/config_generator/config_generator.dart';
import 'package:hiddify/subscription_parser/models/models.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class MultiKernelService {
  MultiKernelService({
    required this.hiddifyCoreService,
    required this.configOptionRepository,
  });

  final HiddifyCoreService hiddifyCoreService;
  final ConfigOptionRepository configOptionRepository;
  final MultiKernelManager _kernelManager = MultiKernelManager();

  KernelType _selectedKernelType = KernelType.singBox;
  ProfileEntity? _currentProfile;
  bool _isConnected = false;

  KernelType get selectedKernelType => _selectedKernelType;
  bool get isConnected => _isConnected;
  KernelStatus get currentStatus => _kernelManager.status;

  Future<void> initialize() async {
    await _kernelManager.switchKernel(_selectedKernelType);
  }

  Future<void> selectKernel(KernelType type) async {
    if (_selectedKernelType == type) return;

    if (_isConnected) {
      await disconnect();
    }

    _selectedKernelType = type;
    await _kernelManager.switchKernel(type);
  }

  Future<List<KernelType>> getAvailableKernels() async {
    return _kernelManager.availableKernelTypes;
  }

  Future<KernelInfo> getKernelInfo(KernelType type) async {
    return _kernelManager.getKernelInfo(type);
  }

  Future<KernelVersionInfo?> checkForUpdate(KernelType type) async {
    return _kernelManager.checkForUpdate(type);
  }

  Future<bool> downloadAndInstallUpdate(
    KernelType type,
    KernelVersionInfo versionInfo, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final result = await _kernelManager.downloadAndInstall(
      type,
      versionInfo,
      onProgress: onProgress,
    );
    return result.success;
  }

  Future<String> generateConfig(
    ProfileEntity profile, {
    List<ProxyNode>? additionalNodes,
    List<ProxyGroup>? additionalGroups,
  }) async {
    final nodes = additionalNodes ?? [];
    final groups = additionalGroups ?? [];

    switch (_selectedKernelType) {
      case KernelType.singBox:
        final config = SingBoxConfigGenerator.generateConfig(
          nodes: nodes,
          groups: groups,
        );
        return SingBoxConfigGenerator.toJsonString(config);

      case KernelType.clashMeta:
        return ClashMetaConfigGenerator.generateConfig(
          nodes: nodes,
          groups: groups,
        );

      case KernelType.v2ray:
        final config = V2RayConfigGenerator.generateConfig(
          nodes: nodes,
        );
        return V2RayConfigGenerator.toJsonString(config);
    }
  }

  Future<void> connect(ProfileEntity profile) async {
    _currentProfile = profile;
    _isConnected = true;
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _currentProfile = null;
  }

  Future<String?> getCurrentConfigContent() async {
    if (_currentProfile == null) return null;

    final dir = await getApplicationSupportDirectory();
    final configDir = Directory(path.join(dir.path, 'configs'));
    if (!await configDir.exists()) return null;

    final configFile = File(path.join(configDir.path, '${_currentProfile!.id}.json'));
    if (!await configFile.exists()) return null;

    return configFile.readAsString();
  }

  Future<String> saveConfigToFile(
    ProfileEntity profile,
    String configContent,
  ) async {
    final dir = await getApplicationSupportDirectory();
    final configDir = Directory(path.join(dir.path, 'configs'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final configFile = File(path.join(configDir.path, '${profile.id}.config'));
    await configFile.writeAsString(configContent);
    return configFile.path;
  }

  Future<void> deleteConfigFile(ProfileEntity profile) async {
    final dir = await getApplicationSupportDirectory();
    final configFile = File(path.join(dir.path, 'configs', '${profile.id}.config'));
    if (await configFile.exists()) {
      await configFile.delete();
    }
  }

  Stream<KernelStatus> watchStatus() {
    return _kernelManager.statusStream;
  }

  void dispose() {
    _kernelManager.dispose();
  }
}
