# Hiddify 增强版需求文档

## 1. 项目概述

### 项目名称
Hiddify Enhanced (hiddify-enhanced)

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

### 2.1 内核支持（修正）

#### 支持的内核
| 内核 | 说明 | 配置文件格式 |
|------|------|-------------|
| sing-box | Hiddify 现有内核 | JSON |
| Clash.Meta | Meta 系列内核（含 mihomo） | YAML |
| v2ray | 官方 v2ray-core | JSON |

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
| 格式 | 类型 | 支持来源 | 支持目标 |
|------|------|---------|---------|
| Clash | YAML | ✓ | ✓ |
| Clash.Meta | YAML | ✓ | ✓ |
| sing-box | JSON | ✓ | ✓ |
| V2Ray | JSON | ✓ | ✓ |
| VMess | URL/JSON | ✓ | ✗ |
| VLESS | URL | ✓ | ✗ |
| Trojan | URL | ✓ | ✗ |
| Shadowsocks | URL | ✓ | ✓ |
| ShadowsocksR | URL | ✓ | ✗ |
| Surge | CONF | ✓ | ✓ |
| Quantumult | CONF | ✓ | ✗ |
| Loon | CONF | ✓ | ✗ |
| WireGuard | INI/JSON | ✓ | ✗ |

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

## 4. 参考项目分析

### 4.1 subconverter 架构（C++）

**核心模块**：
```
src/
├── parser/           # 订阅解析
│   ├── subparser.cpp/h  # 解析入口
│   └── config/      # 配置结构
├── generator/       # 配置生成
│   ├── template/    # 输出模板 (Jinja2)
│   └── config/      # 生成配置
├── lib/             # 核心数据结构
├── config/          # 类型定义
│   ├── proxygroup.h # 代理组定义
│   └── ruleset.h    # 规则集定义
└── utils/           # 工具函数
```

**统一 Proxy 结构**（在 subparser.cpp 中定义）：
- 支持所有协议类型：VMess, VLESS, Trojan, SS, SSR, WireGuard, Hysteria 等
- 统一的构造函数接口
- 格式无关的内部表示

**格式转换流程**：
```
输入格式 → 解析为 Proxy 列表 → 统一数据模型 → 应用模板 → 输出格式
```

### 4.2 FlClash 架构（Flutter）

**目录结构**：
```
lib/
├── core/           # 核心逻辑
│   ├── core.dart   # 核心控制器
│   └── service.dart # 后台服务
├── manager/        # 管理器
│   ├── core_manager.dart    # 内核管理
│   ├── proxy_manager.dart   # 代理管理
│   └── vpn_manager.dart     # VPN/TUN管理
├── models/         # 数据模型
│   ├── clash_config.dart    # Clash配置
│   └── profile.dart         # 订阅配置
└── features/       # 功能模块
```

**特点**：
- 使用 freezed 生成 immutable 模型
- Manager 模式管理各功能模块
- 完整的 TUN/系统代理支持

### 4.3 Hiddify 架构（Flutter - 待补充分析）

（需要克隆 hiddify-app 仓库后深入分析）

---

## 5. 架构设计要点

### 5.1 多内核架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter UI Layer                        │
│    (Hiddify 现有全部界面 + 新增内核选择/订阅管理界面)         │
├─────────────────────────────────────────────────────────────┤
│                    Business Logic Layer                      │
├──────────────────┬──────────────────┬───────────────────────┤
│   KernelManager  │  SubManager      │    ConfigConverter    │
│   (内核管理器)    │  (订阅管理器)    │    (配置转换器)        │
├──────────────────┴──────────────────┴───────────────────────┤
│                     Parser Layer                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │ Clash   │ │sing-box │ │  V2Ray  │ │ Trojan │ ...       │
│  │ Parser  │ │ Parser  │ │ Parser  │ │ Parser │           │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
├─────────────────────────────────────────────────────────────┤
│                      Kernel Layer                            │
│    ┌───────────┐  ┌───────────┐  ┌───────────┐            │
│    │ sing-box  │  │ Clash.Meta│  │   v2ray   │            │
│    │  Kernel   │  │   Kernel  │  │   Kernel  │            │
│    └───────────┘  └───────────┘  └───────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 订阅解析流程（参考 subconverter）

```
┌─────────────────────────────────────────────────────────────┐
│                     Subscription Flow                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  [订阅URL] ──→ [HTTP获取] ──→ [Base64解码?] ──→ [格式检测]  │
│                                              │              │
│                                              ▼              │
│                                    [调用对应Parser解析]      │
│                                              │              │
│                                              ▼              │
│                                    [转换为统一ProxyNode模型]  │
│                                              │              │
│                          ┌───────────────────┴───────────┐  │
│                          ▼                               ▼  │
│                  [存入本地缓存]               [发送到转换器]  │
│                                                     │      │
│                                                     ▼      │
│                                          [加载目标格式模板]  │
│                                                     │      │
│                                                     ▼      │
│                                          [生成目标格式配置]  │
│                                                     │      │
│                                                     ▼      │
│                                          [交给内核管理器]   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 统一节点模型

```dart
class ProxyNode {
    String id;               // 唯一标识 (UUID)
    String name;             // 节点名称
    ProtocolType type;       // 协议类型
    String server;          // 服务器地址
    int port;                // 端口
    String? username;        // 用户名 (可选)
    String? password;         // 密码 (可选)
    
    // 协议特定字段 (Map 存储灵活扩展)
    Map<String, dynamic> options;
    
    // 状态字段
    int? latency;            // 延迟 (ms)
    bool isActive;           // 是否启用
    DateTime? lastChecked;   // 最后检测时间
}

enum ProtocolType {
    // VMess 系列
    vmess,
    
    // VLESS
    vless,
    
    // Trojan 系列
    trojan,
    trojanGo,
    
    // Shadowsocks 系列
    ss,
    ss2022,
    ssr,
    
    // Hysteria 系列
    hysteria,
    hysteria2,
    
    // TUIC
    tuic,
    
    // WireGuard
    wireguard,
    
    // SOCKS/HTTP
    socks5,
    http,
    
    // SSH
    ssh,
}
```

### 5.4 代理组配置（参考 subconverter）

```dart
class ProxyGroup {
    String name;
    GroupType type;          // select, url-test, fallback, load-balance, relay
    List<String> proxies;    // 包含的节点/组名称
    String? url;             // url-test 用的测试URL
    int? interval;           // 测试间隔 (秒)
    int? timeout;            // 超时时间 (秒)
    bool lazy;               // 懒加载
}
```

---

## 6. 实施计划

### Phase 1 - 基础设施（1-2周）
1. Fork Hiddify 仓库，搭建开发环境
2. 分析 Hiddify 现有内核架构
3. 设计统一的 ProxyNode 数据模型
4. 实现基础的 Parser 接口和工厂类

### Phase 2 - sing-box 内核增强（1周）
5. 保持现有 sing-box 内核完全正常工作
6. 增强 sing-box 配置的解析/生成能力

### Phase 3 - 多内核支持（2-3周）
7. 集成 Clash.Meta 内核（mihomo）
8. 集成 v2ray 内核
9. 实现内核切换机制
10. 实现配置格式转换

### Phase 4 - 订阅增强（2周）
11. 实现 Clash 订阅解析
12. 实现 V2Ray 订阅解析
13. 实现格式转换模块（参考 subconverter）
14. 实现订阅合并功能

### Phase 5 - 测试与优化（1-2周）
15. 完整功能测试
16. 性能优化
17. UI/UX 优化
18. 发布准备

---

## 7. 关键决策点

| 决策项 | 选项 | 建议 |
|--------|------|------|
| Parser 实现语言 | Dart vs C++ | Dart (与 Flutter 集成更好) |
| 内核二进制获取 | 预置 vs 动态下载 | 预置基础版 + 动态更新 |
| 配置转换完整性 | 100% vs 最佳 effort | 最佳 effort + 用户提示 |
| 多内核配置冲突 | 隔离 vs 合并 | 配置隔离 + 手动迁移 |
