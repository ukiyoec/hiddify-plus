# Hiddify Plus 需求文档

## 1. 项目概述

### 项目名称
Hiddify Plus (hiddify-plus)

### 项目描述
基于 Hiddify-app 开发的跨平台代理客户端增强版，在保留 Hiddify 全部现有功能（TUN模式、分流规则、完整UI）的基础上，新增多内核支持和多种订阅格式解析转换能力。

### 核心目标
1. **100%保留 Hiddify 现有功能** - 不破坏现有架构
2. **多内核支持** - sing-box、Clash.Meta (mihomo)、v2ray
3. **订阅格式转换** - 参考 subconverter 架构，支持多种格式
4. **跨平台兼容** - 继续支持 Android、iOS、Windows、macOS、Linux

### 技术栈
- **框架**：Flutter + Dart
- **核心内核**：sing-box、Clash.Meta (mihomo)、v2ray
- **订阅转换**：Dart 实现的 subconverter 核心逻辑
- **状态管理**：Provider / Riverpod
- **架构**：Clean Architecture + Feature-First

---

## 2. 功能需求

### 2.1 内核支持

#### 支持的内核
| 内核 | 说明 | 配置文件格式 | 状态 |
|------|------|-------------|------|
| sing-box | Hiddify 现有内核 | JSON | ✅ 已实现 |
| Clash.Meta | Meta 系列内核（含 mihomo） | YAML | ✅ 已实现 |
| v2ray | 官方 v2ray-core | JSON | ✅ 已实现 |

> **注意**：Clash.Meta 和 mihomo 是同一项目，无需重复支持

#### 内核选择
- 系统 SHALL 支持在 sing-box、Clash.Meta、v2ray 三个内核中选择
- WHEN 用户切换内核时，系统 SHALL 自动转换配置格式到目标内核兼容格式
- WHILE 用户未选择内核时，系统 SHALL 默认使用 sing-box 内核

#### 内核管理
- 系统 SHALL 支持从远程服务器下载内核二进制文件
- 系统 SHALL 验证内核文件的完整性和版本信息
- 系统 SHALL 在启动时检测内核版本并在有新版本时提示更新

#### 内核版本更新
- 系统 SHALL 支持自动检测内核最新版本
- 系统 SHALL 支持手动检查更新
- 系统 SHALL 支持自动更新内核到最新版本
- 系统 SHALL 在更新前备份当前内核
- 系统 SHALL 支持回滚到上一个版本
- 系统 SHALL 显示更新进度和状态
- 系统 SHALL 验证更新文件的 SHA256 校验和
- IF 更新失败，系统 SHALL 自动回滚并提示用户

### 2.2 订阅格式支持

#### 支持的输入格式（参考 subconverter）
| 格式 | 类型 | 支持来源 | 支持目标 | 状态 |
|------|------|---------|---------|------|
| Clash | YAML | ✓ | ✓ | ✅ 已实现 |
| Clash.Meta | YAML | ✓ | ✓ | ✅ 已实现 |
| sing-box | JSON | ✓ | ✓ | ✅ 已实现 |
| V2Ray | JSON | ✓ | ✓ | ✅ 已实现 |
| VMess | URL/JSON | ✓ | ✗ | ✅ 已实现 |
| VLESS | URL | ✓ | ✗ | ✅ 已实现 |
| Trojan | URL | ✓ | ✗ | ✅ 已实现 |
| Shadowsocks | URL | ✓ | ✓ | ✅ 已实现 |
| ShadowsocksR | URL | ✓ | ✓ | ✅ 已实现 |
| Surge | CONF | ✓ | ✓ | ✅ 已实现 |
| Quantumult | CONF | ✓ | ✓ | ✅ 已实现 |
| Loon | CONF | ✓ | ✓ | ✅ 已实现 |
| WireGuard | INI/JSON | ✓ | ✓ | ✅ 已实现 |

#### 订阅解析
- 系统 SHALL 解析 HTTP/HTTPS 远程订阅链接
- 系统 SHALL 解析本地配置文件
- 系统 SHALL 支持 Base64 编码的订阅内容
- 系统 SHALL 提取订阅信息：节点列表、剩余流量、到期时间
- 系统 SHALL 支持多个订阅合并

#### 订阅转换
- 系统 SHALL 支持将任意输入格式转换为任意目标格式
- 系统 SHALL 保持节点属性（名称、协议、服务器、端口、加密等）不变
- 系统 SHALL 支持节点过滤、分组和重命名

### 2.3 Hiddify 原有功能保持

#### TUN 模式
- 系统 SHALL 保持完整的 TUN/系统代理模式
- 系统 SHALL 支持自动路由和自定义路由规则

#### 分流规则
- 系统 SHALL 保持现有的分流规则系统
- 系统 SHALL 支持规则导入/导出

#### UI/UX
- 系统 SHALL 保持 Hiddify 现有的全部 UI 界面
- 系统 SHALL 保持现有的设置选项和偏好配置

### 2.4 节点管理

#### 节点选择
- 系统 SHALL 显示所有可用节点及其延迟信息
- WHILE 用户启用自动选择时，系统 SHALL 基于延迟选择最优节点
- 系统 SHALL 支持节点分组和标签筛选

#### 节点测试
- 系统 SHALL 支持批量测试节点延迟
- 系统 SHALL 显示节点的平均延迟、历史延迟统计
- IF 节点连续测试失败，系统 SHALL 自动标记为不可用

---

## 3. 非功能需求

### 3.1 性能
- 订阅解析 SHALL 在 5 秒内完成（1000 节点以内）
- 内核切换 SHALL 在 3 秒内完成
- 内存占用 SHALL 不超过 500MB（不含内核）

### 3.2 兼容性
- 系统 SHALL 保持与 Hiddify 现有 Android、iOS、Windows、macOS、Linux 平台的兼容
- 系统 SHALL 支持 Android 5.0+、iOS 12.0+

### 3.3 安全
- 订阅链接 SHALL 支持 HTTPS
- 用户配置 SHALL 存储在本地加密区域
- 系统 SHALL 不收集用户数据

---

## 4. 已完成功能清单

### 核心模块 ✅

| 模块 | 文件位置 | 测试状态 |
|------|---------|---------|
| subscription_parser | `lib/subscription_parser/` | ✅ 95 tests |
| kernels | `lib/kernels/` | ✅ 95 tests |
| kernel_updater | `lib/kernel_updater/` | ✅ 95 tests |
| 集成测试 | `test/integration/` | ✅ 12 tests |

### 解析器实现 ✅

| 解析器 | 文件 | 支持格式 |
|--------|------|---------|
| ClashParser | `parsers/clash_parser.dart` | YAML, Clash, Clash.Meta |
| SingBoxParser | `parsers/singbox_parser.dart` | JSON, sing-box |
| V2RayParser | `parsers/v2ray_parser.dart` | JSON, V2Ray |
| UriParser | `parsers/uri_parser.dart` | VMess/VLESS/Trojan/SS URI |

### 配置生成器 ✅

| 生成器 | 文件 | 输出格式 |
|--------|------|---------|
| SingBoxConfigGenerator | `config_generator/singbox_config_generator.dart` | JSON |
| ClashMetaConfigGenerator | `config_generator/clash_meta_config_generator.dart` | YAML |
| V2RayConfigGenerator | `config_generator/v2ray_config_generator.dart` | JSON |

---

## 5. 实施计划

### Phase 1 - 基础设施 ✅
1. ✅ Fork Hiddify 仓库，搭建开发环境
2. ✅ 分析 Hiddify 现有内核架构
3. ✅ 设计统一的 ProxyNode 数据模型
4. ✅ 实现基础的 Parser 接口和工厂类

### Phase 2 - sing-box 内核增强 ✅
5. ✅ 保持现有 sing-box 内核完全正常工作
6. ✅ 增强 sing-box 配置的解析/生成能力

### Phase 3 - 多内核支持 ✅
7. ✅ 集成 Clash.Meta 内核（mihomo）
8. ✅ 集成 v2ray 内核
9. ✅ 实现内核切换机制
10. ✅ 实现配置格式转换

### Phase 4 - 订阅增强 ✅
11. ✅ 实现 Clash 订阅解析
12. ✅ 实现 V2Ray 订阅解析
13. ✅ 实现格式转换模块（参考 subconverter）
14. ✅ 实现订阅合并功能

### Phase 5 - 测试与优化 ⏳
15. ⏳ 完整功能测试（部分完成：95+12 测试通过）
16. ⏳ 性能优化
17. ⏳ UI/UX 优化
18. ⏳ 发布准备

---

## 6. 关键决策点

| 决策项 | 选项 | 最终选择 |
|--------|------|---------|
| Parser 实现语言 | Dart vs C++ | Dart (与 Flutter 集成更好) |
| 内核二进制获取 | 预置 vs 动态下载 | 预置基础版 + 动态更新 |
| 配置转换完整性 | 100% vs 最佳 effort | 最佳 effort + 用户提示 |
| 多内核配置冲突 | 隔离 vs 合并 | 配置隔离 + 手动迁移 |

---

## 7. 项目信息

| 项目 | 信息 |
|------|------|
| 项目名称 | hiddify-plus |
| 包名 | hiddify_plus |
| 开发分支 | feat-multi-kernel |
| 仓库地址 | https://github.com/ukiyoec/hiddify-plus |
| 测试数量 | 107 (95 unit + 12 integration) |
| 编译状态 | ✅ 0 errors |
