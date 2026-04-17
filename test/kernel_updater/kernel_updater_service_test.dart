import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/kernel_updater/kernel_version_info.dart';
import 'package:hiddify/kernel_updater/update_settings.dart';
import 'package:hiddify/kernel_updater/kernel_updater_service.dart';

void main() {
  group('KernelType', () {
    test('should have correct display names', () {
      expect(KernelType.singBox.displayName, 'sing-box');
      expect(KernelType.clashMeta.displayName, 'Clash.Meta');
      expect(KernelType.v2ray.displayName, 'v2ray');
    });

    test('should have correct executable names', () {
      expect(KernelType.singBox.executableName, 'sing-box');
      expect(KernelType.clashMeta.executableName, 'mihomo');
      expect(KernelType.v2ray.executableName, 'v2ray');
    });

    test('should have correct latest version URLs', () {
      expect(
        KernelType.singBox.latestVersionUrl,
        'https://api.github.com/repos/SagerNet/sing-box/releases/latest',
      );
      expect(
        KernelType.clashMeta.latestVersionUrl,
        'https://api.github.com/repos/MetaCubeX/mihomo/releases/latest',
      );
      expect(
        KernelType.v2ray.latestVersionUrl,
        'https://api.github.com/repos/v2fly/v2ray-core/releases/latest',
      );
    });

    test('should have correct download base URLs', () {
      expect(
        KernelType.singBox.downloadBaseUrl,
        'https://github.com/SagerNet/sing-box/releases/download',
      );
      expect(
        KernelType.clashMeta.downloadBaseUrl,
        'https://github.com/MetaCubeX/mihomo/releases/download',
      );
      expect(
        KernelType.v2ray.downloadBaseUrl,
        'https://github.com/v2fly/v2ray-core/releases/download',
      );
    });
  });

  group('KernelVersionInfo', () {
    test('should create with required fields', () {
      final info = KernelVersionInfo(
        type: KernelType.singBox,
        version: '1.8.0',
        downloadUrl: 'https://example.com/download',
        sha256: 'abc123',
        fileSize: 1024,
        releaseDate: DateTime(2024, 1, 1),
      );

      expect(info.type, KernelType.singBox);
      expect(info.version, '1.8.0');
      expect(info.downloadUrl, 'https://example.com/download');
      expect(info.sha256, 'abc123');
      expect(info.fileSize, 1024);
      expect(info.releaseDate, DateTime(2024, 1, 1));
      expect(info.releaseNotes, '');
      expect(info.isMandatory, false);
      expect(info.minAppVersion, '');
    });

    test('should create with all fields', () {
      final info = KernelVersionInfo(
        type: KernelType.clashMeta,
        version: '1.18.0',
        downloadUrl: 'https://example.com/mihomo',
        sha256: 'def456',
        fileSize: 2048,
        releaseDate: DateTime(2024, 6, 15),
        releaseNotes: 'Bug fixes and improvements',
        isMandatory: true,
        minAppVersion: '2.0.0',
      );

      expect(info.releaseNotes, 'Bug fixes and improvements');
      expect(info.isMandatory, true);
      expect(info.minAppVersion, '2.0.0');
    });

    test('should serialize to JSON and back', () {
      final original = KernelVersionInfo(
        type: KernelType.v2ray,
        version: '5.0.0',
        downloadUrl: 'https://example.com/v2ray',
        sha256: 'ghi789',
        fileSize: 3072,
        releaseDate: DateTime(2024, 3, 20),
        releaseNotes: 'New features',
        isMandatory: false,
        minAppVersion: '2.1.0',
      );

      final json = original.toJson();
      final restored = KernelVersionInfo.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.version, original.version);
      expect(restored.downloadUrl, original.downloadUrl);
      expect(restored.sha256, original.sha256);
      expect(restored.fileSize, original.fileSize);
      expect(restored.releaseNotes, original.releaseNotes);
      expect(restored.isMandatory, original.isMandatory);
      expect(restored.minAppVersion, original.minAppVersion);
    });
  });

  group('KernelLocalInfo', () {
    test('should create with required fields', () {
      final info = KernelLocalInfo(
        type: KernelType.singBox,
        version: '1.8.0',
        installedPath: '/path/to/sing-box',
        installedDate: DateTime(2024, 1, 15),
      );

      expect(info.type, KernelType.singBox);
      expect(info.version, '1.8.0');
      expect(info.installedPath, '/path/to/sing-box');
      expect(info.installedDate, DateTime(2024, 1, 15));
      expect(info.backupPath, isNull);
    });

    test('should create with backup path', () {
      final info = KernelLocalInfo(
        type: KernelType.clashMeta,
        version: '1.18.0',
        installedPath: '/path/to/mihomo',
        installedDate: DateTime(2024, 6, 20),
        backupPath: '/path/to/backup/mihomo',
      );

      expect(info.backupPath, '/path/to/backup/mihomo');
    });

    test('should support copyWith', () {
      final original = KernelLocalInfo(
        type: KernelType.v2ray,
        version: '5.0.0',
        installedPath: '/path/to/v2ray',
        installedDate: DateTime(2024, 3, 25),
      );

      final updated = original.copyWith(
        version: '5.0.1',
        backupPath: '/path/to/backup',
      );

      expect(updated.type, KernelType.v2ray);
      expect(updated.version, '5.0.1');
      expect(updated.installedPath, '/path/to/v2ray');
      expect(updated.backupPath, '/path/to/backup');
    });

    test('should serialize to JSON and back', () {
      final original = KernelLocalInfo(
        type: KernelType.singBox,
        version: '1.8.0',
        installedPath: '/path/to/sing-box',
        installedDate: DateTime(2024, 1, 15),
        backupPath: '/path/to/backup',
      );

      final json = original.toJson();
      final restored = KernelLocalInfo.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.version, original.version);
      expect(restored.installedPath, original.installedPath);
      expect(restored.backupPath, original.backupPath);
    });
  });

  group('UpdateSettings', () {
    test('should create with default values', () {
      const settings = UpdateSettings();

      expect(settings.autoCheckEnabled, true);
      expect(settings.autoDownloadEnabled, false);
      expect(settings.autoInstallEnabled, false);
      expect(settings.installOnStartup, true);
      expect(settings.channel, UpdateChannel.stable);
      expect(settings.checkInterval, const Duration(days: 1));
    });

    test('should create with custom values', () {
      final settings = UpdateSettings(
        autoCheckEnabled: false,
        autoDownloadEnabled: true,
        autoInstallEnabled: true,
        installOnStartup: false,
        channel: UpdateChannel.beta,
        checkInterval: const Duration(hours: 12),
      );

      expect(settings.autoCheckEnabled, false);
      expect(settings.autoDownloadEnabled, true);
      expect(settings.autoInstallEnabled, true);
      expect(settings.installOnStartup, false);
      expect(settings.channel, UpdateChannel.beta);
      expect(settings.checkInterval, const Duration(hours: 12));
    });

    test('should serialize to JSON and back', () {
      final original = UpdateSettings(
        autoCheckEnabled: false,
        autoDownloadEnabled: true,
        autoInstallEnabled: true,
        installOnStartup: false,
        channel: UpdateChannel.dev,
        checkInterval: const Duration(hours: 6),
      );

      final json = original.toJson();
      final restored = UpdateSettings.fromJson(json);

      expect(restored.autoCheckEnabled, original.autoCheckEnabled);
      expect(restored.autoDownloadEnabled, original.autoDownloadEnabled);
      expect(restored.autoInstallEnabled, original.autoInstallEnabled);
      expect(restored.installOnStartup, original.installOnStartup);
      expect(restored.channel, original.channel);
    });

    test('should handle UpdateChannel values', () {
      expect(UpdateChannel.stable.displayName, '稳定版');
      expect(UpdateChannel.beta.displayName, '测试版');
      expect(UpdateChannel.dev.displayName, '开发版');
    });
  });

  group('UpdateResult', () {
    test('should create success result', () {
      final versionInfo = KernelVersionInfo(
        type: KernelType.singBox,
        version: '1.8.0',
        downloadUrl: 'https://example.com',
        sha256: 'abc',
        fileSize: 100,
        releaseDate: DateTime.now(),
      );

      final result = UpdateResult(
        success: true,
        newVersion: versionInfo,
      );

      expect(result.success, true);
      expect(result.newVersion, versionInfo);
      expect(result.errorMessage, isNull);
    });

    test('should create failure result', () {
      const result = UpdateResult(
        success: false,
        errorMessage: 'Download failed',
      );

      expect(result.success, false);
      expect(result.errorMessage, 'Download failed');
      expect(result.newVersion, isNull);
    });
  });

  group('DownloadProgress', () {
    test('should create with all fields', () {
      const progress = DownloadProgress(
        received: 500,
        total: 1000,
        percentage: 0.5,
      );

      expect(progress.received, 500);
      expect(progress.total, 1000);
      expect(progress.percentage, 0.5);
    });

    test('should handle zero total', () {
      const progress = DownloadProgress(
        received: 0,
        total: 0,
        percentage: 0,
      );

      expect(progress.total, 0);
      expect(progress.percentage, 0);
    });
  });
}