import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/kernel_updater/kernel_updater.dart';
import 'package:hiddify/kernel_updater/providers/update_settings_provider.dart';
import 'package:hiddify/kernels/kernel_manager.dart';
import 'package:hiddify/kernels/providers/kernel_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class KernelOptionsPage extends HookConsumerWidget {
  const KernelOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKernel = ref.watch(selectedKernelTypeProvider);
    final kernelsAsync = ref.watch(availableKernelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kernel Settings'),
      ),
      body: ListView(
        children: [
          kernelsAsync.when(
            data: (kernels) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Kernel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...kernels.map((kernel) => _KernelOptionTile(
                  kernel: kernel,
                  isSelected: selectedKernel == kernel,
                  onTap: () => _selectKernel(context, ref, kernel),
                )),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(8),
                const _UpdateSettingsSection(),
              ],
            ),
          ),
          const Divider(),
          const _KernelInfoSection(),
        ],
      ),
    );
  }

  Future<void> _selectKernel(BuildContext context, WidgetRef ref, KernelType kernel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Kernel'),
        content: Text('Switch to ${kernel.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(selectedKernelTypeProvider.notifier).state = kernel;
      await ref.read(multiKernelServiceProvider).selectKernel(kernel);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to ${kernel.displayName}')),
        );
      }
    }
  }
}

class _KernelOptionTile extends StatelessWidget {
  const _KernelOptionTile({
    required this.kernel,
    required this.isSelected,
    required this.onTap,
  });

  final KernelType kernel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(
        _getKernelIcon(kernel),
        size: 32,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        kernel.displayName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : null,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: Text(_getKernelDescription(kernel)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  IconData _getKernelIcon(KernelType kernel) {
    return switch (kernel) {
      KernelType.singBox => Icons.hub_rounded,
      KernelType.clashMeta => Icons.shield_rounded,
      KernelType.v2ray => Icons.public_rounded,
    };
  }

  String _getKernelDescription(KernelType kernel) {
    return switch (kernel) {
      KernelType.singBox => 'sing-box core, recommended',
      KernelType.clashMeta => 'Clash.Meta (mihomo) core',
      KernelType.v2ray => 'v2ray-core',
    };
  }
}

class _UpdateSettingsSection extends ConsumerWidget {
  const _UpdateSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(updateSettingsProvider);
    final settingsNotifier = ref.read(updateSettingsProvider.notifier);

    return Column(
      children: [
        SwitchListTile.adaptive(
          title: const Text('Auto check updates'),
          subtitle: const Text('Automatically check for kernel updates'),
          value: settings.autoCheckEnabled,
          onChanged: (value) => settingsNotifier.updateAutoCheck(value),
        ),
        SwitchListTile.adaptive(
          title: const Text('Auto download'),
          subtitle: const Text('Automatically download updates'),
          value: settings.autoDownloadEnabled,
          onChanged: (value) => settingsNotifier.updateAutoDownload(value),
        ),
        SwitchListTile.adaptive(
          title: const Text('Install on startup'),
          subtitle: const Text('Install updates when app starts'),
          value: settings.installOnStartup,
          onChanged: (value) => settingsNotifier.updateAutoInstall(value),
        ),
        ListTile(
          title: const Text('Check for updates now'),
          leading: const Icon(Icons.refresh_rounded),
          onTap: () async {
            final updater = ref.read(kernelUpdaterServiceProvider);
            for (final type in KernelType.values) {
              final update = await updater.checkForUpdate(type);
              if (update != null) {
                if (context.mounted) {
                  _showUpdateDialog(context, ref, update);
                }
                return;
              }
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All kernels are up to date')),
              );
            }
          },
        ),
      ],
    );
  }

  void _showUpdateDialog(BuildContext context, WidgetRef ref, KernelVersionInfo update) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update available: ${update.version}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Release date: ${update.releaseDate}'),
            if (update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(update.releaseNotes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = ref.read(multiKernelServiceProvider);
              await service.downloadAndInstallUpdate(update.type, update);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _KernelInfoSection extends ConsumerWidget {
  const _KernelInfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKernel = ref.watch(selectedKernelTypeProvider);

    return FutureBuilder<KernelInfo?>(
      future: ref.read(multiKernelServiceProvider).getKernelInfo(selectedKernel).then((info) => info),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final info = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current kernel info',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(8),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(info.type.displayName),
                subtitle: Text('Version: ${info.version}'),
              ),
            ],
          ),
        );
      },
    );
  }
}
