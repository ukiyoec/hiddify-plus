import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'kernel_version_info.dart';
import 'update_settings.dart';

class UpdateResult {
  final bool success;
  final String? errorMessage;
  final KernelVersionInfo? newVersion;

  const UpdateResult({
    required this.success,
    this.errorMessage,
    this.newVersion,
  });
}

class DownloadProgress {
  final int received;
  final int total;
  final double percentage;

  const DownloadProgress({
    required this.received,
    required this.total,
    required this.percentage,
  });
}

class KernelUpdaterService {
  static final KernelUpdaterService _instance = KernelUpdaterService._internal();
  factory KernelUpdaterService() => _instance;
  KernelUpdaterService._internal();

  UpdateSettings _settings = const UpdateSettings();
  final Map<KernelType, KernelLocalInfo?> _localInfoCache = {};

  UpdateSettings get settings => _settings;

  Future<void> loadSettings() async {
    final file = await _getSettingsFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _settings = UpdateSettings.fromJson(json);
    }
  }

  Future<void> saveSettings() async {
    final file = await _getSettingsFile();
    await file.writeAsString(jsonEncode(_settings.toJson()));
  }

  void updateSettings(UpdateSettings newSettings) {
    _settings = newSettings;
    saveSettings();
  }

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(path.join(dir.path, 'kernel_updater_settings.json'));
  }

  Future<KernelLocalInfo?> getLocalInfo(KernelType type) async {
    if (_localInfoCache.containsKey(type)) {
      return _localInfoCache[type];
    }

    final executablePath = await _getKernelExecutablePath(type);
    final file = File(executablePath);

    if (!await file.exists()) {
      _localInfoCache[type] = null;
      return null;
    }

    final version = await _getKernelVersion(type, executablePath);
    _localInfoCache[type] = KernelLocalInfo(
      type: type,
      version: version,
      installedPath: executablePath,
      installedDate: await file.lastModified(),
    );

    return _localInfoCache[type];
  }

  Future<String> _getKernelExecutablePath(KernelType type) async {
    final dir = await getApplicationSupportDirectory();
    final kernelDir = Directory(path.join(dir.path, 'kernels', type.name));
    if (!await kernelDir.exists()) {
      await kernelDir.create(recursive: true);
    }
    return path.join(kernelDir.path, type.executableName);
  }

  Future<String> _getKernelVersion(KernelType type, String executablePath) async {
    try {
      final result = await Process.run(executablePath, ['--version']);
      final output = result.stdout.toString();
      final match = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(output);
      return match?.group(1) ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  Future<KernelVersionInfo?> checkForUpdate(KernelType type) async {
    try {
      final response = await http.get(
        Uri.parse(type.latestVersionUrl),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      final localInfo = await getLocalInfo(type);
      if (localInfo != null && _compareVersions(localInfo.version, version) >= 0) {
        return null;
      }

      final assets = json['assets'] as List<dynamic>? ?? [];
      final asset = _findMatchingAsset(assets, type);

      if (asset == null) {
        return null;
      }

      final bodyContent = json['body'] as String? ?? '';
      final isMandatory = bodyContent.toLowerCase().contains('[mandatory]') ||
          bodyContent.toLowerCase().contains('[force update]');

      return KernelVersionInfo(
        type: type,
        version: version,
        downloadUrl: asset['browser_download_url'] as String,
        sha256: _extractSha256FromAsset(asset) ?? '',
        fileSize: asset['size'] as int? ?? 0,
        releaseDate: DateTime.parse(json['published_at'] as String),
        releaseNotes: bodyContent,
        isMandatory: isMandatory,
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _findMatchingAsset(List<dynamic> assets, KernelType type) {
    final platform = Platform.operatingSystem.toLowerCase();
    final arch = Platform.localHostname.contains('arm') || 
                 Platform.localHostname.contains('aarch64') 
        ? 'arm64' 
        : 'amd64';

    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.contains(platform) && name.contains(arch)) {
        return asset as Map<String, dynamic>;
      }
    }

    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.contains('linux') && name.contains('64')) {
        return asset as Map<String, dynamic>;
      }
    }

    return null;
  }

  String? _extractSha256FromAsset(Map<String, dynamic> asset) {
    final name = (asset['name'] as String).toLowerCase();
    if (name.endsWith('.sha256') || name.endsWith('.sha256sum')) {
      return null;
    }
    return null;
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  Future<UpdateResult> downloadAndInstall(
    KernelType type,
    KernelVersionInfo versionInfo, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    try {
      final executablePath = await _getKernelExecutablePath(type);
      final backupPath = await _createBackup(type);

      final request = http.Request('GET', Uri.parse(versionInfo.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        return UpdateResult(
          success: false,
          errorMessage: '下载失败: HTTP ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? versionInfo.fileSize;
      var receivedBytes = 0;
      final chunks = <int>[];

      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(DownloadProgress(
          received: receivedBytes,
          total: totalBytes,
          percentage: totalBytes > 0 ? receivedBytes / totalBytes : 0,
        ));
      }

      final fileBytes = chunks.toList();
      final actualSha256 = sha256.convert(fileBytes).toString();

      if (versionInfo.sha256.isNotEmpty && actualSha256 != versionInfo.sha256) {
        await _restoreBackup(type, backupPath);
        return const UpdateResult(
          success: false,
          errorMessage: 'SHA256 校验失败',
        );
      }

      final file = File(executablePath);
      await file.writeAsBytes(fileBytes);
      await Process.run('chmod', ['755', executablePath]);

      _localInfoCache[type] = KernelLocalInfo(
        type: type,
        version: versionInfo.version,
        installedPath: executablePath,
        installedDate: DateTime.now(),
        backupPath: backupPath,
      );

      await _cleanupOldBackups(type);

      return UpdateResult(
        success: true,
        newVersion: versionInfo,
      );
    } catch (e) {
      return UpdateResult(
        success: false,
        errorMessage: '安装失败: $e',
      );
    }
  }

  Future<String> _createBackup(KernelType type) async {
    final executablePath = await _getKernelExecutablePath(type);
    final file = File(executablePath);

    if (!await file.exists()) {
      return '';
    }

    final dir = await getApplicationSupportDirectory();
    final backupDir = Directory(path.join(dir.path, 'kernels', type.name, 'backup'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final backupPath = path.join(backupDir.path, '${type.executableName}.backup');
    await file.copy(backupPath);

    return backupPath;
  }

  Future<void> _restoreBackup(KernelType type, String backupPath) async {
    if (backupPath.isEmpty) return;

    final backupFile = File(backupPath);
    if (!await backupFile.exists()) return;

    final executablePath = await _getKernelExecutablePath(type);
    await backupFile.copy(executablePath);
  }

  Future<void> _cleanupOldBackups(KernelType type) async {
    final dir = await getApplicationSupportDirectory();
    final backupDir = Directory(path.join(dir.path, 'kernels', type.name, 'backup'));
    
    if (!await backupDir.exists()) return;

    final files = await backupDir.list().toList();
    if (files.length <= 1) return;

    files.sort((a, b) => a.path.compareTo(b.path));
    for (var i = 0; i < files.length - 1; i++) {
      await files[i].delete();
    }
  }

  Future<bool> rollback(KernelType type) async {
    try {
      final localInfo = await getLocalInfo(type);
      if (localInfo?.backupPath == null) {
        return false;
      }

      final backupFile = File(localInfo!.backupPath!);
      if (!await backupFile.exists()) {
        return false;
      }

      final executablePath = await _getKernelExecutablePath(type);
      await backupFile.copy(executablePath);

      _localInfoCache[type] = localInfo.copyWith(
        version: await _getKernelVersion(type, executablePath),
        installedDate: DateTime.now(),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> autoUpdateIfNeeded() async {
    if (!_settings.autoCheckEnabled) return;

    for (final type in KernelType.values) {
      final updateInfo = await checkForUpdate(type);
      if (updateInfo == null) continue;

      if (_settings.autoDownloadEnabled && _settings.autoInstallEnabled) {
        await downloadAndInstall(type, updateInfo);
      }
    }
  }
}
