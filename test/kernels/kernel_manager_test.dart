import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/kernels/kernel_manager.dart';
import 'package:hiddify/kernel_updater/kernel_version_info.dart';
import 'package:hiddify/subscription_parser/models/models.dart';

class MockKernelManager implements IKernelManager {
  KernelInfo? _activeKernel;
  KernelType? _activeKernelType;
  KernelStatus _status = KernelStatus.stopped;
  final _statusController = StreamController<KernelStatus>.broadcast();

  @override
  KernelInfo? get activeKernel => _activeKernel;

  @override
  KernelType? get activeKernelType => _activeKernelType;

  @override
  KernelStatus get status => _status;

  @override
  Stream<KernelStatus> get statusStream => _statusController.stream;

  @override
  Future<KernelInfo> getKernelInfo(KernelType type) async {
    return KernelInfo(
      type: type,
      version: '1.0.0',
      status: KernelStatus.stopped,
    );
  }

  @override
  Future<bool> switchKernel(KernelType type) async {
    _activeKernelType = type;
    _activeKernel = await getKernelInfo(type);
    return true;
  }

  @override
  Future<bool> start(KernelConfig config) async {
    _status = KernelStatus.starting;
    _statusController.add(_status);
    await Future.delayed(const Duration(milliseconds: 10));
    _status = KernelStatus.running;
    _statusController.add(_status);
    return true;
  }

  @override
  Future<bool> stop() async {
    _status = KernelStatus.stopping;
    _statusController.add(_status);
    await Future.delayed(const Duration(milliseconds: 10));
    _status = KernelStatus.stopped;
    _statusController.add(_status);
    return true;
  }

  @override
  Future<bool> restart() async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 10));
    _status = KernelStatus.running;
    _statusController.add(_status);
    return true;
  }

  @override
  Future<bool> downloadKernel(KernelType type, String url) async {
    return true;
  }

  @override
  Future<String?> getKernelVersion(KernelType type) async {
    return '1.0.0';
  }

  void dispose() {
    _statusController.close();
  }
}

void main() {
  group('KernelStatus', () {
    test('should have correct isRunning values', () {
      expect(KernelStatus.stopped.isRunning, false);
      expect(KernelStatus.starting.isRunning, false);
      expect(KernelStatus.running.isRunning, true);
      expect(KernelStatus.stopping.isRunning, false);
      expect(KernelStatus.error.isRunning, false);
    });

    test('should have correct isStopped values', () {
      expect(KernelStatus.stopped.isStopped, true);
      expect(KernelStatus.starting.isStopped, false);
      expect(KernelStatus.running.isStopped, false);
      expect(KernelStatus.stopping.isStopped, false);
      expect(KernelStatus.error.isStopped, false);
    });
  });

  group('KernelInfo', () {
    test('should create KernelInfo with required fields', () {
      const info = KernelInfo(
        type: KernelType.singBox,
        version: '1.8.0',
        status: KernelStatus.running,
      );

      expect(info.type, KernelType.singBox);
      expect(info.version, '1.8.0');
      expect(info.status, KernelStatus.running);
      expect(info.downloadUrl, isNull);
      expect(info.lastUpdated, isNull);
    });

    test('should create KernelInfo with all fields', () {
      final now = DateTime.now();
      final info = KernelInfo(
        type: KernelType.clashMeta,
        version: '1.18.0',
        status: KernelStatus.running,
        downloadUrl: 'https://example.com/mihomo',
        lastUpdated: now,
      );

      expect(info.downloadUrl, 'https://example.com/mihomo');
      expect(info.lastUpdated, now);
    });

    test('should support copyWith', () {
      const original = KernelInfo(
        type: KernelType.singBox,
        version: '1.8.0',
        status: KernelStatus.stopped,
      );

      final updated = original.copyWith(
        status: KernelStatus.running,
        version: '1.8.1',
      );

      expect(updated.type, KernelType.singBox);
      expect(updated.version, '1.8.1');
      expect(updated.status, KernelStatus.running);
    });
  });

  group('KernelConfig', () {
    test('should create KernelConfig with required fields', () {
      const config = KernelConfig(
        kernelType: KernelType.singBox,
        nodes: [],
      );

      expect(config.kernelType, KernelType.singBox);
      expect(config.nodes, isEmpty);
      expect(config.groups, isEmpty);
    });

    test('should create KernelConfig with nodes and groups', () {
      final nodes = [
        const ProxyNode(
          id: '1',
          remark: 'Test Node',
          type: ProxyType.vmess,
          server: 'example.com',
          port: 8080,
        ),
      ];

      final groups = [
        const ProxyGroup(
          name: 'auto',
          type: GroupType.select,
        ),
      ];

      final config = KernelConfig(
        kernelType: KernelType.clashMeta,
        nodes: nodes,
        groups: groups,
      );

      expect(config.nodes.length, 1);
      expect(config.groups.length, 1);
    });

    test('should create KernelConfig with options', () {
      const config = KernelConfig(
        kernelType: KernelType.v2ray,
        nodes: [],
        options: {'dns': {'servers': ['8.8.8.8']}},
      );

      expect(config.options, isNotNull);
      expect(config.options!['dns'], isNotNull);
    });
  });

  group('IKernelManager (Mock)', () {
    late MockKernelManager manager;

    setUp(() {
      manager = MockKernelManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('should start and stop kernel', () async {
      expect(manager.status, KernelStatus.stopped);

      await manager.switchKernel(KernelType.singBox);
      expect(manager.activeKernelType, KernelType.singBox);

      await manager.start(const KernelConfig(
        kernelType: KernelType.singBox,
        nodes: [],
      ));
      expect(manager.status, KernelStatus.running);

      await manager.stop();
      expect(manager.status, KernelStatus.stopped);
    });

    test('should switch between kernels', () async {
      await manager.switchKernel(KernelType.singBox);
      expect(manager.activeKernelType, KernelType.singBox);

      await manager.switchKernel(KernelType.clashMeta);
      expect(manager.activeKernelType, KernelType.clashMeta);

      await manager.switchKernel(KernelType.v2ray);
      expect(manager.activeKernelType, KernelType.v2ray);
    });

    test('should get kernel version', () async {
      final version = await manager.getKernelVersion(KernelType.singBox);
      expect(version, '1.0.0');
    });

    test('should get kernel info', () async {
      final info = await manager.getKernelInfo(KernelType.clashMeta);
      expect(info.type, KernelType.clashMeta);
      expect(info.version, '1.0.0');
    });

    test('should restart kernel', () async {
      await manager.start(const KernelConfig(
        kernelType: KernelType.singBox,
        nodes: [],
      ));
      expect(manager.status, KernelStatus.running);

      await manager.restart();
      expect(manager.status, KernelStatus.running);
    });

    test('should download kernel', () async {
      final result = await manager.downloadKernel(
        KernelType.singBox,
        'https://example.com/sing-box',
      );
      expect(result, true);
    });
  });

  group('KernelException', () {
    test('should create with message only', () {
      final exception = KernelException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.kernelType, isNull);
      expect(exception.originalError, isNull);
    });

    test('should create with kernel type', () {
      final exception = KernelException(
        'Kernel not found',
        kernelType: KernelType.singBox,
      );
      expect(exception.message, 'Kernel not found');
      expect(exception.kernelType, KernelType.singBox);
    });

    test('should create with original error', () {
      final originalError = Exception('Original');
      final exception = KernelException(
        'Wrapped error',
        originalError: originalError,
      );
      expect(exception.originalError, originalError);
    });

    test('should format to string', () {
      final exception = KernelException('Test error');
      expect(exception.toString(), 'KernelException: Test error');
    });
  });
}