import 'package:hiddify/kernel_updater/kernel_updater_service.dart';
import 'package:hiddify/kernel_updater/update_settings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final kernelUpdaterServiceProvider = Provider<KernelUpdaterService>((ref) {
  return KernelUpdaterService();
});

final updateSettingsProvider = StateNotifierProvider<UpdateSettingsNotifier, UpdateSettings>((ref) {
  final service = ref.watch(kernelUpdaterServiceProvider);
  return UpdateSettingsNotifier(service);
});

class UpdateSettingsNotifier extends StateNotifier<UpdateSettings> {
  final KernelUpdaterService _service;

  UpdateSettingsNotifier(this._service) : super(const UpdateSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.loadSettings();
    state = _service.settings;
  }

  Future<void> updateAutoCheck(bool enabled) async {
    final newSettings = state.copyWith(autoCheckEnabled: enabled);
    state = newSettings;
    _service.updateSettings(newSettings);
  }

  Future<void> updateAutoDownload(bool enabled) async {
    final newSettings = state.copyWith(autoDownloadEnabled: enabled);
    state = newSettings;
    _service.updateSettings(newSettings);
  }

  Future<void> updateAutoInstall(bool enabled) async {
    final newSettings = state.copyWith(autoInstallEnabled: enabled);
    state = newSettings;
    _service.updateSettings(newSettings);
  }

  Future<void> updateChannel(UpdateChannel channel) async {
    final newSettings = state.copyWith(channel: channel);
    state = newSettings;
    _service.updateSettings(newSettings);
  }

  Future<void> updateCheckInterval(Duration interval) async {
    final newSettings = state.copyWith(checkInterval: interval);
    state = newSettings;
    _service.updateSettings(newSettings);
  }
}
