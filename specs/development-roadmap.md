# Hiddify Enhanced 开发路线文档

本文档记录 hiddify-enhanced 项目的完整开发过程，每一步操作都有详细记录，避免遗忘。

---

## 开发信息

- **项目名称**: hiddify-enhanced
- **项目路径**: `/workspace/hiddify-enhanced`
- **开发分支**: `260417-feat-multi-kernel-subscription`
- **创建日期**: 2026-04-17
- **最后更新**: 2026-04-17

---

## 第一阶段：项目初始化

### 步骤 1.1: Fork 原项目

**日期**: 2026-04-17
**操作**: 将 `hiddify/hiddify-app` 项目克隆到本地

**执行命令**:
```bash
cd /workspace
git clone https://github.com/hiddify/hiddify-app.git hiddify-enhanced
```

**结果**: 
- 项目已克隆到 `/workspace/hiddify-enhanced`
- 默认分支为 master/main

### 步骤 1.2: 创建开发分支

**日期**: 2026-04-17
**操作**: 基于当前日期创建开发分支

**执行命令**:
```bash
cd /workspace/hiddify-enhanced
git checkout -b 260417-feat-multi-kernel-subscription
```

**分支命名规则**: `YYMMDD-feat-xxxxx-xxxx-xxxx`
- `260417` = 2026年04月17日
- `feat-multi-kernel-subscription` = 功能描述

**结果**: 已切换到新创建的分支

### 步骤 1.3: 检查 .gitmodules

**日期**: 2026-04-17
**操作**: 检查项目是否包含 Git Submodules

**执行命令**:
```bash
git submodule status
```

**结果**: 项目不包含 submodules，跳过 submodule 初始化

---

## 第二阶段：代码分析与架构设计

### 步骤 2.1: 分析 Hiddify 现有架构

**日期**: 2026-04-17
**分析内容**:
- Flutter 前端使用 Riverpod + freezed 状态管理
- 订阅管理在 `lib/features/profile/`
- 核心通信通过 gRPC 与 `hiddify-core` (Go-based on sing-box) 交互
- ProfileParser 已支持 URI 协议检测 (VMess/VLESS/Trojan/SS)

### 步骤 2.2: 分析参考项目

**日期**: 2026-04-17
**参考项目分析**:

| 项目 | Stars | 关键发现 |
|------|-------|----------|
| FlClash | 36.3k | 完整的 Clash.Meta 客户端，成熟的内核管理架构 |
| Karing | 11k | sing-box/Clash 路由支持 |
| subconverter | 16.4k | 订阅格式转换引擎，支持 20+ 格式 |

**重要发现**: Clash.Meta 和 mihomo 是同一项目，无需重复支持

### 步骤 2.3: 创建规格文档

**日期**: 2026-04-17
**创建文件**:
- `.monkeycode/specs/hiddify-enhanced/requirements.md` - 需求文档
- `.monkeycode/specs/hiddify-enhanced/design.md` - 技术设计文档

---

## 第三阶段：订阅解析模块开发

### 步骤 3.1: 创建订阅解析模块目录

**日期**: 2026-04-17
**创建目录**:
```
lib/subscription_parser/
├── subscription_parser.dart
├── models/
│   ├── models.dart
│   ├── proxy_node.dart
│   └── subscription.dart
├── parsers/
│   ├── base/
│   │   └── parser.dart
│   ├── format_detector.dart
│   ├── parser_factory.dart
│   ├── clash_parser.dart
│   ├── singbox_parser.dart
│   ├── v2ray_parser.dart
│   └── uri_parser.dart
└── services/
    ├── subscription_service.dart
    └── converter.dart
```

### 步骤 3.2: 实现统一 ProxyNode 模型

**日期**: 2026-04-17
**文件**: `lib/subscription_parser/models/proxy_node.dart`

**核心字段**:
- `id`: UUID 唯一标识
- `remark`: 节点名称
- `type`: 协议类型 (vmess/vless/trojan/ss 等)
- `server`: 服务器地址
- `port`: 端口
- `username/password`: 认证信息
- `tlsSecure/sni/fingerprint`: TLS 相关
- `latency/isActive/lastChecked`: 状态信息

### 步骤 3.3: 实现订阅服务

**日期**: 2026-04-17
**文件**: `lib/subscription_parser/services/subscription_service.dart`

**功能**:
- `fetchSubscription(url)`: HTTP 获取订阅内容
- `decodeContent(content)`: Base64 解码
- `detectFormat(content)`: 自动格式检测
- `parseNodes(content, format)`: 解析为 ProxyNode 列表

### 步骤 3.4: 实现格式解析器

**日期**: 2026-04-17
**解析器实现**:

| 解析器 | 文件 | 支持格式 |
|--------|------|----------|
| ClashParser | `parsers/clash_parser.dart` | YAML, Clash, Clash.Meta |
| SingBoxParser | `parsers/singbox_parser.dart` | JSON, sing-box |
| V2RayParser | `parsers/v2ray_parser.dart` | JSON, V2Ray |
| UriParser | `parsers/uri_parser.dart` | VMess/VLESS/Trojan/SS URI |

### 步骤 3.5: 实现格式转换器

**日期**: 2026-04-17
**文件**: `lib/subscription_parser/services/converter.dart`

**功能**:
- 将统一 ProxyNode 模型转换为目标格式配置
- 支持 Clash YAML、sing-box JSON、V2Ray JSON 等格式输出

---

## 第四阶段：多内核架构开发

### 步骤 4.1: 创建内核目录结构

**日期**: 2026-04-17
**创建目录**:
```
lib/kernels/
├── kernels.dart
├── kernel_manager.dart
├── multi_kernel_manager.dart
├── singbox_kernel.dart
├── clash_meta_kernel.dart
└── v2ray_kernel.dart
```

### 步骤 4.2: 实现内核接口

**日期**: 2026-04-17
**文件**: `lib/kernels/kernel_manager.dart`

**接口定义**:
```dart
abstract class IKernel {
    String get name;
    String get version;
    KernelStatus get status;
    Future<bool> start(String config);
    Future<bool> stop();
    Future<bool> restart();
    Future<bool> update();
}
```

### 步骤 4.3: 实现 MultiKernelManager

**日期**: 2026-04-17
**文件**: `lib/kernels/multi_kernel_manager.dart`

**功能**:
- 管理多个内核实例
- 切换活跃内核
- 统一配置分发

### 步骤 4.4: 实现各内核实现类

**日期**: 2026-04-17
**实现类**:

| 类名 | 文件 | 说明 |
|------|------|------|
| SingBoxKernel | `singbox_kernel.dart` | sing-box 内核 |
| ClashMetaKernel | `clash_meta_kernel.dart` | Clash.Meta (mihomo) 内核 |
| V2RayKernel | `v2ray_kernel.dart` | v2ray-core 内核 |

---

## 第五阶段：内核版本更新功能

### 步骤 5.1: 创建内核更新服务目录

**日期**: 2026-04-17
**创建目录**:
```
lib/kernel_updater/
├── kernel_updater.dart
├── kernel_updater_service.dart
├── kernel_version_info.dart
└── update_settings.dart
```

### 步骤 5.2: 实现版本信息模型

**日期**: 2026-04-17
**文件**: `lib/kernel_updater/kernel_version_info.dart`

**核心字段**:
- `type`: 内核类型
- `version`: 版本号
- `downloadUrl`: 下载地址
- `sha256`: SHA256 校验和
- `releaseDate`: 发布日期
- `isMandatory`: 是否强制更新

### 步骤 5.3: 实现更新设置模型

**日期**: 2026-04-17
**文件**: `lib/kernel_updater/update_settings.dart`

**核心字段**:
- `autoCheckEnabled`: 自动检查更新
- `autoDownloadEnabled`: 自动下载更新
- `autoInstallEnabled`: 自动安装更新
- `installOnStartup`: 启动时安装
- `channel`: 更新通道 (stable/beta/dev)

### 步骤 5.4: 实现内核更新服务

**日期**: 2026-04-17
**文件**: `lib/kernel_updater/kernel_updater_service.dart`

**功能**:
- `checkForUpdate(type)`: 检查是否有新版本
- `downloadAndInstall(type, onProgress)`: 下载并安装
- `autoUpdateIfNeeded()`: 自动更新检查
- `rollback()`: 回滚到上一版本
- `verifyDownload(path, expectedHash)`: 验证下载文件

---

## 第六阶段：集成到 Hiddify

### 步骤 6.1: 添加依赖

**日期**: 2026-04-17
**修改文件**: `pubspec.yaml`

**添加依赖**:
```yaml
dependencies:
    yaml: ^3.1.2
```

**执行命令**:
```bash
cd /workspace/hiddify-enhanced
flutter pub get
```

### 步骤 6.2: 创建增强解析器

**日期**: 2026-04-17
**创建文件**: `lib/features/profile/data/enhanced_profile_parser.dart`

**功能**:
- 集成 subscription_parser 模块
- 提供与 Hiddify 现有 ProfileParser 兼容的接口
- 复用现有订阅解析逻辑

---

## 第七阶段：测试与验证

### 步骤 7.1: 代码生成 (TODO)

**状态**: 待完成
**待执行命令**:
```bash
cd /workspace/hiddify-enhanced
dart run build_runner build
```

### 步骤 7.2: 单元测试 (TODO)

**状态**: 待完成
**待执行**:
- 各 Parser 的格式解析正确性测试
- 格式转换完整性测试
- KernelManager 状态机测试

### 步骤 7.3: 集成测试 (TODO)

**状态**: 待完成
**待执行**:
- 订阅获取-解析-转换完整流程测试
- 内核启动-运行-停止生命周期测试
- 多内核切换的配置迁移测试

---

## Git 提交记录

### 提交 1: 初始项目克隆

**日期**: 2026-04-17
**操作**: 克隆 hiddify/hiddify-app 项目

### 提交 2: 创建开发分支

**日期**: 2026-04-17
**操作**: 创建并切换到 `260417-feat-multi-kernel-subscription` 分支

### 提交 3: 添加订阅解析模块

**日期**: 2026-04-17
**提交信息**: `feat: add subscription_parser module with multi-format support`

**变更文件**:
- `lib/subscription_parser/` (新增目录)
- `pubspec.yaml` (添加 yaml 依赖)

### 提交 4: 添加多内核架构

**日期**: 2026-04-17
**提交信息**: `feat: add multi-kernel support and enhanced subscription parsing`

**变更文件**:
- `lib/kernels/` (新增目录)
- `lib/features/profile/data/enhanced_profile_parser.dart` (新增文件)

### 提交 5: 添加内核版本更新功能

**日期**: 2026-04-17
**提交信息**: `feat: add kernel version update service with auto-update support`

**变更文件**:
- `lib/kernel_updater/` (新增目录)
- `pubspec.yaml` (添加 crypto、http 依赖)

### 提交 6: 更新需求和设计文档

**日期**: 2026-04-17
**提交信息**: `docs: update requirements and design documents with kernel update feature`

**变更文件**:
- `.monkeycode/specs/hiddify-enhanced/requirements.md`
- `.monkeycode/specs/hiddify-enhanced/design.md`
- `.monkeycode/specs/hiddify-enhanced/development-roadmap.md` (新增)

### 提交 7: 增强内核实现

**日期**: 2026-04-17
**提交信息**: `feat: enhance kernel implementations with config generators`

**变更文件**:
- `lib/kernels/config_generator/` (新增目录)
  - `singbox_config_generator.dart`
  - `clash_meta_config_generator.dart`
  - `v2ray_config_generator.dart`
  - `config_generator.dart`
- `lib/kernels/kernel_manager.dart` (统一 KernelType 枚举)
- `lib/kernels/singbox_kernel.dart` (增强实现)
- `lib/kernels/clash_meta_kernel.dart` (增强实现)
- `lib/kernels/v2ray_kernel.dart` (增强实现)
- `lib/kernels/multi_kernel_manager.dart` (增强实现)

### 提交 8: 修复语法错误

**日期**: 2026-04-17
**提交信息**: `fix: resolve syntax errors and freezed initialization`

**变更文件**:
- `lib/subscription_parser/parsers/clash_parser.dart`
- `lib/kernel_updater/kernel_updater_service.dart`
- `lib/subscription_parser/models/subscription.dart`

### 提交 9: 集成 MultiKernelService

**日期**: 2026-04-17
**提交信息**: `feat: add MultiKernelService integration with HiddifyCoreService`

**变更文件**:
- `lib/kernels/service/multi_kernel_service.dart` (新增)
- `lib/kernels/service/service.dart` (新增)
- `lib/kernels/providers/kernel_providers.dart` (新增)
- `lib/kernels/kernels.dart` (更新导出)

### 提交 10: 添加内核选择 UI

**日期**: 2026-04-17
**提交信息**: `feat: add kernel selection UI and settings page`

**变更文件**:
- `lib/features/settings/overview/sections/kernel/kernel_options_page.dart` (新增)
- `lib/features/settings/overview/settings_page.dart` (添加内核设置入口)
- `lib/core/router/go_router/routing_config_notifier.dart` (添加路由)

### 提交 11: 添加配置转换器

**日期**: 2026-04-17
**提交信息**: `feat: add ConfigConverter for kernel config conversion`

**变更文件**:
- `lib/kernels/config_converter/config_converter.dart` (新增)

### 提交 12: 整合 subscription_parser 和 ConfigConverter

**日期**: 2026-04-17
**提交信息**: `refactor: integrate subscription_parser and ConfigConverter`

**变更文件**:
- `lib/subscription_parser/services/converter.dart` (重构)
- `lib/kernels/config_converter/config_converter.dart` (重构)

**整合内容**:
- `SubscriptionConverter` 成为统一入口点
- 添加 `KernelType` 支持
- 添加 `nodesToKernel()` 和 `convertToKernel()` 方法
- 添加 `generateDefaultGroups()` 方法
- `ConfigConverter` 现在委托给 `SubscriptionConverter`

---

## 常见问题与解决方案

### Q1: 内核二进制从哪里获取？

**A**: 
- sing-box: https://github.com/SagerNet/sing-box/releases
- Clash.Meta (mihomo): https://github.com/MetaCubeX/mihomo/releases
- v2ray: https://github.com/v2fly/v2ray-core/releases

### Q2: 如何验证下载的内核文件？

**A**: 
1. 下载时记录 SHA256 校验和
2. 下载完成后计算本地文件的 SHA256
3. 比对两者是否一致
4. 不一致则重新下载或报错

### Q3: 更新失败如何回滚？

**A**:
1. 更新前备份当前内核到 `~/.config/hiddify-{kernel}/backup/`
2. 更新失败时，从备份目录复制回原位置
3. 删除损坏的新版本文件

### Q4: 如何添加新的订阅格式支持？

**A**:
1. 在 `lib/subscription_parser/models/` 中添加新的数据模型
2. 在 `lib/subscription_parser/parsers/` 中实现新的解析器类
3. 在 `ParserFactory` 中注册新的解析器
4. 在 `Converter` 中添加对应的格式生成逻辑

---

## 下一步待办事项

### 高优先级
1. [x] 完成内核实现的实际二进制下载和启动逻辑
2. [x] 与 HiddifyCoreService 集成
3. [x] 添加内核选择的 UI 界面
4. [x] 实现内核间配置格式转换
5. [x] 运行 `build_runner` 生成 freezed/json_serializable 代码

### 中优先级
6. [ ] 编写订阅解析器的单元测试
7. [ ] 编写内核管理器的单元测试
8. [ ] 编写集成测试
9. [ ] 实现更新设置的持久化

### 低优先级
10. [ ] 优化解析性能（1000 节点 < 5 秒）
11. [ ] 实现订阅合并的高级功能
12. [ ] 添加节点延迟测试功能
13. [ ] 实现规则的导入/导出

---

## 附录：关键文件路径

### 项目文件
| 路径 | 说明 |
|------|------|
| `/workspace/hiddify-enhanced/` | 项目根目录 |
| `/workspace/hiddify-enhanced/lib/` | Dart 源代码目录 |
| `/workspace/hiddify-enhanced/pubspec.yaml` | Flutter 依赖配置 |
| `/workspace/hiddify-enhanced/README.md` | 项目说明 |

### 新增模块
| 路径 | 说明 |
|------|------|
| `/workspace/hiddify-enhanced/lib/subscription_parser/` | 订阅解析模块 |
| `/workspace/hiddify-enhanced/lib/kernels/` | 多内核架构 |
| `/workspace/hiddify-enhanced/lib/kernels/config_generator/` | 各内核配置生成器 |
| `/workspace/hiddify-enhanced/lib/kernel_updater/` | 内核版本更新服务 |
| `/workspace/hiddify-enhanced/lib/features/profile/data/enhanced_profile_parser.dart` | 增强解析器 |

### 文档文件
| 路径 | 说明 |
|------|------|
| `/workspace/.monkeycode/specs/hiddify-enhanced/requirements.md` | 需求文档 |
| `/workspace/.monkeycode/specs/hiddify-enhanced/design.md` | 技术设计文档 |
| `/workspace/.monkeycode/specs/hiddify-enhanced/development-roadmap.md` | 开发路线文档 |
| `/workspace/.monkeycode/MEMORY.md` | 用户指令记忆 |
