import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_settings.freezed.dart';
part 'update_settings.g.dart';

enum UpdateChannel {
  stable,
  beta,
  dev,
}

@freezed
class UpdateSettings with _$UpdateSettings {
  const factory UpdateSettings({
    @Default(true) bool autoCheckEnabled,
    @Default(false) bool autoDownloadEnabled,
    @Default(false) bool autoInstallEnabled,
    @Default(true) bool installOnStartup,
    @Default(UpdateChannel.stable) UpdateChannel channel,
    @Default(Duration(days: 1)) Duration checkInterval,
  }) = _UpdateSettings;

  factory UpdateSettings.fromJson(Map<String, dynamic> json) =>
      _$UpdateSettingsFromJson(json);
}

extension UpdateChannelExtension on UpdateChannel {
  String get displayName {
    switch (this) {
      case UpdateChannel.stable:
        return '稳定版';
      case UpdateChannel.beta:
        return '测试版';
      case UpdateChannel.dev:
        return '开发版';
    }
  }
}
