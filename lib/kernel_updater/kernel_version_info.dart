import 'package:freezed_annotation/freezed_annotation.dart';

part 'kernel_version_info.freezed.dart';
part 'kernel_version_info.g.dart';

enum KernelType {
  singBox,
  clashMeta,
  v2ray,
}

@freezed
class KernelVersionInfo with _$KernelVersionInfo {
  const factory KernelVersionInfo({
    required KernelType type,
    required String version,
    required String downloadUrl,
    required String sha256,
    required int fileSize,
    required DateTime releaseDate,
    @Default('') String releaseNotes,
    @Default(false) bool isMandatory,
    @Default('') String minAppVersion,
  }) = _KernelVersionInfo;

  factory KernelVersionInfo.fromJson(Map<String, dynamic> json) =>
      _$KernelVersionInfoFromJson(json);
}

@freezed
class KernelLocalInfo with _$KernelLocalInfo {
  const factory KernelLocalInfo({
    required KernelType type,
    required String version,
    required String installedPath,
    required DateTime installedDate,
    String? backupPath,
  }) = _KernelLocalInfo;

  factory KernelLocalInfo.fromJson(Map<String, dynamic> json) =>
      _$KernelLocalInfoFromJson(json);
}

extension KernelTypeExtension on KernelType {
  String get displayName {
    switch (this) {
      case KernelType.singBox:
        return 'sing-box';
      case KernelType.clashMeta:
        return 'Clash.Meta';
      case KernelType.v2ray:
        return 'v2ray';
    }
  }

  String get executableName {
    switch (this) {
      case KernelType.singBox:
        return 'sing-box';
      case KernelType.clashMeta:
        return 'mihomo';
      case KernelType.v2ray:
        return 'v2ray';
    }
  }

  String get latestVersionUrl {
    switch (this) {
      case KernelType.singBox:
        return 'https://api.github.com/repos/SagerNet/sing-box/releases/latest';
      case KernelType.clashMeta:
        return 'https://api.github.com/repos/MetaCubeX/mihomo/releases/latest';
      case KernelType.v2ray:
        return 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest';
    }
  }

  String get downloadBaseUrl {
    switch (this) {
      case KernelType.singBox:
        return 'https://github.com/SagerNet/sing-box/releases/download';
      case KernelType.clashMeta:
        return 'https://github.com/MetaCubeX/mihomo/releases/download';
      case KernelType.v2ray:
        return 'https://github.com/v2fly/v2ray-core/releases/download';
    }
  }
}
