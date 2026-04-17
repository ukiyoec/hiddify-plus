# hiddify-plus

hiddify-plus 是基于 [Hiddify](https://github.com/hiddify/hiddify-app) 项目 fork 的增强版本。

## 项目起源

hiddify-plus 从 [Hiddify](https://github.com/hiddify/hiddify-app) fork 而来。Hiddify 是一款基于 [Sing-box](https://github.com/SagerNet/sing-box) 通用代理工具的跨平台代理客户端。

## 新增功能

相比原版 Hiddify，hiddify-plus 增加了以下功能：

### 多内核支持

hiddify-plus 支持多种代理内核，可以根据需要选择不同的内核：

| 内核 | 说明 |
|------|------|
| sing-box | 原版主要使用的内核 |
| Clash.Meta | 支持 Clash 配置格式 |
| v2ray | 支持 V2Ray 配置格式 |

### 增强的订阅解析

- 支持更多订阅格式的解析和转换
- 支持 sing-box、V2ray、Clash、Clash Meta 配置格式
- 配置格式互相转换功能

### 内核更新服务

- 支持内核版本管理
- 支持内核自动更新
- 提供内核版本信息显示

## 技术特性

- 多平台客户端：Android、Windows、macOS 和 Linux
- 简单易用的用户界面
- 基于延迟自动选择节点
- 支持自动更新订阅
- 显示配置文件信息（剩余天数、流量使用情况）
- 深色和浅色模式
- 兼容多种代理管理面板

## 技术架构

### 核心模块

| 模块 | 路径 | 说明 |
|------|------|------|
| subscription_parser | lib/subscription_parser/ | 订阅格式解析和转换 |
| kernels | lib/kernels/ | 多内核架构 |
| kernel_updater | lib/kernel_updater/ | 内核更新服务 |
| ConfigConverter | lib/kernels/config_converter/ | 配置格式转换器 |

### 开发环境

详见 [build-environment.md](./docs/build-environment.md)

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

## 许可证

本项目遵循原版 Hiddify 的开源许可证。
