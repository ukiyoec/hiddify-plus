# hiddify-plus 项目文档

## 目录

- [项目概述](#项目概述)
- [需求文档](./requirements.md)
- [技术设计](./design.md)
- [开发路线](./development-roadmap.md)
- [构建环境](./build-environment.md)

---

## 项目概述

### 项目起源

hiddify-plus 是基于 [Hiddify](https://github.com/hiddify/hiddify-app) 项目 fork 的增强版本。

| 属性 | 值 |
|------|-----|
| 原版仓库 | https://github.com/hiddify/hiddify-app |
| 原版 Stars | 28,713 |
| 原版最新版本 | v4.1.2 |
| hiddify-core 分支 | v3 |

**Hiddify 是什么？** 一款基于 [Sing-box](https://github.com/SagerNet/sing-box) 通用代理工具的跨平台代理客户端，提供了自动选择节点、TUN 模式、远程配置文件等功能，无广告且代码开源。

### Fork 目的

hiddify-plus 在原版基础上进行以下增强：

| 增强功能 | 说明 |
|---------|------|
| 多内核支持 | 支持 sing-box、Clash.Meta、v2ray 多种内核 |
| 增强订阅解析 | 支持更多订阅格式的解析和转换 |
| 配置转换器 | 实现不同内核配置格式的互相转换 |
| 内核更新服务 | 支持内核版本管理和自动更新 |

### 技术架构

#### 核心模块

| 模块 | 路径 | 说明 |
|------|------|------|
| subscription_parser | lib/subscription_parser/ | 订阅格式解析和转换 |
| kernels | lib/kernels/ | 多内核架构 |
| kernel_updater | lib/kernel_updater/ | 内核更新服务 |
| ConfigConverter | lib/kernels/config_converter/ | 配置格式转换器 |

#### 技术栈

| 组件 | 版本/信息 |
|------|----------|
| Flutter | 3.38.5 |
| 包名 | app.hiddify.com |
| Android SDK | 36 |
| Kotlin | 2.1.0 |
| Java | OpenJDK 17 |
| NDK | 28.2.13676358 |

### 支持的内核

| 内核 | 配置文件格式 | 状态 |
|------|-------------|------|
| sing-box | JSON | ✅ 已实现 |
| Clash.Meta | YAML | ✅ 已实现 |
| v2ray | JSON | ✅ 已实现 |

### 版本信息

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-04-17 | 初始版本，基于 Hiddify v4.1.2 |

---

## 快速开始

### 环境要求

- Flutter 3.38.5+
- Dart 3.10.4+
- Java 17+
- Android SDK 36
- NDK 28.2.13676358

### 构建命令

```bash
# 安装依赖
flutter pub get

# 生成代码
dart run build_runner build --delete-conflicting-outputs

# Android APK 构建
flutter build apk --release

# 运行测试
flutter test
```

详细环境配置请参阅 [构建环境](./build-environment.md)。

---

## 致谢

本项目基于以下开源项目，感谢这些项目的贡献者：

- [Sing-box](https://github.com/SagerNet/sing-box)
- [Sing-box for Android](https://github.com/SagerNet/sing-box-for-android)
- [Sing-box for Apple](https://github.com/SagerNet/sing-box-for-apple)
- [Clash](https://github.com/Dreamacro/clash)
- [Clash Meta](https://github.com/MetaCubeX/Clash.Meta)
- [FClash](https://github.com/Fclash/Fclash)
- [Vazirmatn Font by Saber Rastikerdar](https://github.com/rastikerdar/vazirmatn)
- [原版 Hiddify](https://github.com/hiddify/hiddify-app)

---

## 许可证

本项目遵循原版 Hiddify 的开源许可证。
