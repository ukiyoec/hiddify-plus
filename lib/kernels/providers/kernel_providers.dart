import 'package:hiddify/features/settings/data/config_option_data_providers.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hiddify/kernels/kernel_manager.dart';
import 'package:hiddify/kernels/service/multi_kernel_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final multiKernelServiceProvider = Provider<MultiKernelService>((ref) {
  final hiddifyCoreService = ref.watch(hiddifyCoreServiceProvider);
  final configOptionRepository = ref.watch(configOptionRepositoryProvider);

  final service = MultiKernelService(
    hiddifyCoreService: hiddifyCoreService,
    configOptionRepository: configOptionRepository,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final selectedKernelTypeProvider = StateProvider<KernelType>((ref) {
  return KernelType.singBox;
});

final availableKernelsProvider = FutureProvider<List<KernelType>>((ref) async {
  final service = ref.watch(multiKernelServiceProvider);
  return service.getAvailableKernels();
});

final kernelInfoProvider = FutureProvider.family<KernelInfo, KernelType>((ref, type) async {
  final service = ref.watch(multiKernelServiceProvider);
  return service.getKernelInfo(type);
});
