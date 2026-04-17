# Hiddify Plus 开发路线文档

本文档记录 hiddify-plus 项目的完整开发过程。

---

## 开发信息

| 项目 | 信息 |
|------|------|
| 项目名称 | hiddify-plus |
| 包名 | hiddify_plus |
| 项目路径 | `/workspace/hiddify-plus` |
| 开发分支 | `feat-multi-kernel` |
| 仓库地址 | https://github.com/ukiyoec/hiddify-plus |
| 创建日期 | 2026-04-17 |
| 最后更新 | 2026-04-17 |

---

## 第一阶段：项目初始化 ✅

### 步骤 1.1: Fork 原项目

**日期**: 2026-04-17
**操作**: 将 `hiddify/hiddify-app` 项目克隆到本地并重命名

**执行命令**:
```bash
git clone https://github.com/hiddify/hiddify-app.git hiddify-plus
```

### 步骤 1.2: 创建开发分支

**日期**: 2026-04-17
**操作**: 基于当前日期创建开发分支

**执行命令**:
```bash
cd hiddify-plus
git checkout -b feat-multi-kernel
```

### 步骤 1.3: 重命名项目和包名

**日期**: 2026-04-17
**修改文件**: `pubspec.yaml`
**变更**:
- 项目名称: `hiddify_plus`
- 包名: `hiddify_plus`

### 步骤 1.4: 检查 .gitmodules

**日期**: 2026-04-17
**结果**: 项目不包含 submodules

---

## 第二阶段：订阅解析模块开发 ✅

### 步骤 2.1: 创建订阅解析模块

**日期**: 2026-04-17
**目录**: `lib/subscription_parser/`

```
lib/subscription_parser/
├── subscription_parser.dart
├── models/
│   ├── models.dart
│   ├── proxy_node.dart
│   └── subscription.dart
├── parsers/
│   ├── parsers.dart
│   ├── format_detector.dart
│   ├── parser_factory.dart
│   ├── clash_parser.dart
│   ├── singbox_parser.dart
│   ├── v2ray_parser.dart
│   └── uri_parser.dart
└── services/
    ├── services.dart
    ├── subscription_service.dart
    └── converter.dart
```

### 步骤 2.2: 实现 ProxyNode 模型

**日期**: 2026-04-17
**文件**: `lib/subscription_parser/models/proxy_node.dart`

**核心字段**:
- `id`: UUID 唯一标识
- `remark`: 节点名称
- `type`: ProxyType 协议类型
- `server`: 服务器地址
- `port`: 端口
- TLS、网络、插件等扩展字段

### 步骤 2.3: 实现格式解析器

**日期**: 2026-04-17
**解析器**:

| 解析器 | 文件 | 支持格式 |
|--------|------|---------|
| ClashParser | `parsers/clash_parser.dart` | YAML, Clash, Clash.Meta |
| SingBoxParser | `parsers/singbox_parser.dart` | JSON, sing-box |
| V2RayParser | `parsers/v2ray_parser.dart` | JSON, V2Ray |
| UriParser | `parsers/uri_parser.dart` | VMess/VLESS/Trojan/SS URI |

### 步骤 2.4: 实现格式转换器

**日期**: 2026-04-17
**文件**: `lib/subscription_parser/services/converter.dart`

**功能**:
- `convert()`: 格式间转换
- `convertToKernel()`: 转换为内核配置
- `parseOnly()`: 仅解析
- `mergeSubscriptions()`: 订阅合并
- `splitByProtocol()`: 按协议分割
- `filterByProtocol()`: 按协议过滤
- `filterByName()`: 按名称过滤

---

## 第三阶段：多内核架构开发 ✅

### 步骤 3.1: 创建内核目录结构

**日期**: 2026-04-17
**目录**: `lib/kernels/`

```
lib/kernels/
├── kernels.dart
├── kernel_manager.dart
├── multi_kernel_manager.dart
├── singbox_kernel.dart
├── clash_meta_kernel.dart
├── v2ray_kernel.dart
├── config_converter/
├── config_generator/
├── providers/
└── service/
```

### 步骤 3.2: 实现内核接口

**日期**: 2026-04-17
**文件**: `lib/kernels/kernel_manager.dart`

**接口定义**:
```dart
abstract class IKernelManager {
  Future<KernelInfo> getKernelInfo(KernelType type);
  KernelInfo? get activeKernel;
  KernelType? get activeKernelType;
  KernelStatus get status;
  
  Future<bool> switchKernel(KernelType type);
  Future<bool> start(KernelConfig config);
  Future<bool> stop();
  Future<bool> restart();
  
  Future<bool> downloadKernel(KernelType type, String url);
  Future<String?> getKernelVersion(KernelType type);
  
  Stream<KernelStatus> get statusStream;
}
```

### 步骤 3.3: 实现 MultiKernelManager

**日期**: 2026-04-17
**文件**: `lib/kernels/multi_kernel_manager.dart`

### 步骤 3.4: 实现各内核实现类

| 类名 | 文件 | 说明 |
|------|------|------|
| SingBoxKernel | `singbox_kernel.dart` | sing-box 内核 |
| ClashMetaKernel | `clash_meta_kernel.dart` | Clash.Meta (mihomo) 内核 |
| V2RayKernel | `v2ray_kernel.dart` | v2ray-core 内核 |

### 步骤 3.5: 实现配置生成器

**日期**: 2026-04-17
**目录**: `lib/kernels/config_generator/`

| 生成器 | 文件 | 输出格式 |
|--------|------|---------|
| SingBoxConfigGenerator | `singbox_config_generator.dart` | JSON |
| ClashMetaConfigGenerator | `clash_meta_config_generator.dart` | YAML |
| V2RayConfigGenerator | `v2ray_config_generator.dart` | JSON |

---

## 第四阶段：内核版本更新功能 ✅

### 步骤 4.1: 创建内核更新服务目录

**日期**: 2026-04-17
**目录**: `lib/kernel_updater/`

```
lib/kernel_updater/
├── kernel_updater.dart
├── kernel_updater_service.dart
├── kernel_version_info.dart
├── update_settings.dart
└── providers/
    └── update_settings_provider.dart
```

### 步骤 4.2: 实现版本信息模型

**日期**: 2026-04-17
**文件**: `lib/kernel_updater/kernel_version_info.dart`

**核心字段**:
- `type`: KernelType
- `version`: 版本号
- `downloadUrl`: 下载地址
- `sha256`: SHA256 校验和
- `releaseDate`: 发布日期
- `isMandatory`: 是否强制更新

### 步骤 4.3: 实现更新设置模型

**日期**: 2026-04-17
**文件**: `lib/kernel_updater/update_settings.dart`

### 步骤 4.4: 实现内核更新服务

**日期**: 2026-04-17
**文件**: `lib/kernel_updater/kernel_updater_service.dart`

---

## 第五阶段：集成与测试 ✅

### 步骤 5.1: 代码生成

**日期**: 2026-04-17
**执行命令**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**结果**: 成功生成 freezed/json_serializable 代码

### 步骤 5.2: 修复编译错误

**日期**: 2026-04-17
**修复内容**:
- 添加缺失的 imports
- 修复类型冲突（ProxyType, SubscriptionInfo）
- 修复 Map→JSON 字符串转换
- 删除重复方法

### 步骤 5.3: 运行测试

**日期**: 2026-04-17
**执行命令**:
```bash
flutter test
```

**结果**:
- 单元测试: 95 passed
- 集成测试: 12 passed
- **总计: 107 tests passed**

---

## Git 提交记录

### 提交列表

| # | 日期 | 提交信息 |
|---|------|---------|
| 1 | 2026-04-17 | 初始项目克隆 |
| 2 | 2026-04-17 | feat: add subscription_parser module |
| 3 | 2026-04-17 | feat: add multi-kernel support |
| 4 | 2026-04-17 | feat: add kernel updater service |
| 5 | 2026-04-17 | feat: add config generators |
| 6 | 2026-04-17 | fix: resolve syntax errors |
| 7 | 2026-04-17 | feat: add MultiKernelService |
| 8 | 2026-04-17 | feat: add kernel selection UI |
| 9 | 2026-04-17 | refactor: integrate subscription_parser |
| 10 | 2026-04-17 | docs: move specs to project |
| 11 | 2026-04-17 | fix: resolve compilation errors |
| 12 | 2026-04-17 | docs: move specs to hiddify-plus/specs/ |

---

## 测试结果

### 单元测试

| 模块 | 测试数 | 状态 |
|------|--------|------|
| subscription_parser | 58+ | ✅ |
| kernels | 18 | ✅ |
| kernel_updater | 19 | ✅ |

### 集成测试

| 模块 | 测试数 | 状态 |
|------|--------|------|
| subscription_integration_test | 12 | ✅ |

---

## 下一步待办事项

### 高优先级
- [ ] 将新模块与 Hiddify 主应用 UI 集成
- [ ] 添加内核切换 UI
- [ ] 测试实际订阅解析和内核切换流程

### 中优先级
- [ ] 优化解析性能（1000 节点 < 5 秒）
- [ ] 实现订阅合并的高级功能
- [ ] 添加节点延迟测试功能

### 低优先级
- [ ] 实现规则的导入/导出
- [ ] 添加 Surge/Quantumult/Loon 格式支持

---

## 附录：关键文件路径

### 项目文件
| 路径 | 说明 |
|------|------|
| `/workspace/hiddify-plus/` | 项目根目录 |
| `/workspace/hiddify-plus/lib/` | Dart 源代码目录 |
| `/workspace/hiddify-plus/pubspec.yaml` | Flutter 依赖配置 |
| `/workspace/hiddify-plus/specs/` | 项目文档 |

### 新增模块
| 路径 | 说明 |
|------|------|
| `/workspace/hiddify-plus/lib/subscription_parser/` | 订阅解析模块 |
| `/workspace/hiddify-plus/lib/kernels/` | 多内核架构 |
| `/workspace/hiddify-plus/lib/kernel_updater/` | 内核版本更新服务 |
| `/workspace/hiddify-plus/lib/features/profile/data/enhanced_profile_parser.dart` | 增强解析器 |

### 文档文件
| 路径 | 说明 |
|------|------|
| `/workspace/hiddify-plus/specs/requirements.md` | 需求文档 |
| `/workspace/hiddify-plus/specs/design.md` | 技术设计文档 |
| `/workspace/hiddify-plus/specs/development-roadmap.md` | 开发路线文档 |
