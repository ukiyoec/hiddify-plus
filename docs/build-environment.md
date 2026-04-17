# hiddify-plus Build Environment Configuration

本文档记录 hiddify-plus 项目编译成功所使用的所有配置环境信息。

---

## 一、Flutter SDK 配置

| 属性 | 值 |
|------|-----|
| Flutter 版本 | 3.38.5 |
| Dart 版本 | (与 Flutter 3.38.5 绑定) |
| Channel | stable |
| SDK 要求 | ^3.10.4 |

### 安装方式 (Linux/macOS)

```bash
# 使用 Flutter SDK Manager
flutter install 3.38.5
# 或直接下载
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.5-stable.tar.xz
tar xf flutter_linux_3.38.5-stable.tar.xz
export PATH="$PATH:/path/to/flutter/bin"
```

### Windows

```powershell
# 使用 winget
winget install Google/flutter
# 或直接下载
# https://docs.flutter.dev/get-started/install/windows
```

---

## 二、Android SDK 配置

| 属性 | 值 |
|------|-----|
| Android SDK Path | /usr/local/lib/android/sdk (CI) 或 $ANDROID_HOME |
| compileSdkVersion | 36 |
| targetSdkVersion | 36 |
| minSdkVersion | (使用 Flutter 默认) |
| NDK Version | 28.2.13676358 |

### Android Build Tools

| 组件 | 版本 |
|------|------|
| Android Gradle Plugin (AGP) | 8.6.0 |
| Build Tools | (由 AGP 自动管理) |

### Android SDK Manager 安装命令

```bash
# 安装 Android SDK (Linux)
export ANDROID_HOME=/usr/local/lib/android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# 接受 license
yes | sdkmanager --licenses

# 安装必需组件
sdkmanager "platforms;android-36"
sdkmanager "build-tools;36.0.0"
sdkmanager "ndk;28.2.13676358"
sdkmanager "cmake;3.22.1"
```

---

## 三、Java 配置

| 属性 | 值 |
|------|-----|
| Java 版本 | OpenJDK 17.0.18 |
| Java Runtime | OpenJDK Runtime Environment (build 17.0.18+8-Debian-1deb12u1) |
| JVM Target | 17 |
| Java Source Compatibility | JavaVersion.VERSION_17 |

### Java 安装方式

```bash
# Ubuntu/Debian
apt-get install openjdk-17-jdk

# macOS (使用 Homebrew)
brew install openjdk@17

# Windows
# 下载 https://adoptium.net/temurin/releases/?version=17
```

### 设置 JAVA_HOME

```bash
# Linux/macOS
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Ubuntu
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

---

## 四、Gradle 配置

| 属性 | 值 |
|------|-----|
| Gradle Version | (由 AGP 8.6.0 自动管理) |
| Gradle Plugin Portal | gradlePluginPortal() |
| Daemon | enabled |
| Parallel Build | enabled |
| Configuration Cache | enabled |
| Build Cache | enabled |

### Gradle Properties 配置

```properties
# android/gradle.properties
org.gradle.jvmargs=-Xmx4048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
android.defaults.buildfeatures.buildconfig=true
android.nonTransitiveRClass=false
android.nonFinalResIds=false
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.configureondemand=true
org.gradle.caching=true
```

---

## 五、Kotlin 配置

| 属性 | 值 |
|------|-----|
| Kotlin Version | 2.1.0 |
| Kotlin Plugin ID | org.jetbrains.kotlin.android |
| JVM Target | 17 |

### Kotlin Gradle Plugin 配置

```groovy
// android/settings.gradle
plugins {
    id "org.jetbrains.kotlin.android" version "2.1.0" apply false
}
```

---

## 六、Android App 配置

### 关键配置项

```groovy
// android/app/build.gradle
android {
    namespace 'com.hiddify.hiddify'
    testNamespace "test.com.hiddify.hiddify"
    compileSdkVersion 36
    ndkVersion "28.2.13676358"
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = '17'
    }
    
    defaultConfig {
        applicationId "app.hiddify.com"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion 36
        multiDexEnabled true
    }
}
```

### ProGuard/R8 配置

项目使用默认的 R8 压缩配置，无特殊定制。

---

## 七、项目依赖版本

### 核心 Flutter 依赖

```yaml
dependencies:
  flutter: ^3.38.5
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
  
  # State Management
  hooks_riverpod: ^2.4.10
  flutter_hooks: ^0.20.5
  riverpod_annotation: ^2.3.4
  
  # Code Generation
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0
  dart_mappable: ^4.2.1
  
  # Networking
  dio: ^5.4.1
  dio_smart_retry: ^7.0.1
  
  # Database
  drift: ^2.21.0
  drift_flutter: ^0.2.1
  sqlite3_flutter_libs: ^0.5.28
  
  # i18n
  slang: ^4.8.1
  slang_flutter: ^4.8.0
  
  # Utilities
  rxdart: ^0.28.0
  fpdart: ^1.1.0
  uuid: ^4.3.3
  path_provider: ^2.1.1
  shared_preferences: ^2.5.2
  
  # gRPC/Protobuf
  grpc: ^4.0.1
  protobuf: ^2.0.0
```

### 开发依赖

```yaml
dev_dependencies:
  build_runner: ^2.4.13
  json_serializable: ^6.7.1
  freezed: ^2.4.7
  riverpod_generator: ^2.4.3
  drift_dev: ^2.21.0
  slang_build_runner: ^4.4.0
  flutter_gen_runner: ^5.4.0
  dart_mappable_builder: ^4.2.1
  ffigen: ^19.1.0
  lint: ^2.3.0
```

### Android 原生依赖

```groovy
dependencies {
    implementation 'com.google.code.gson:gson:2.11.0'
    implementation 'androidx.core:core-ktx:1.16.0'
    implementation 'androidx.appcompat:appcompat:1.7.0'
    implementation 'androidx.lifecycle:lifecycle-livedata-ktx:2.8.7'
    implementation "androidx.compose.ui:ui:1.7.8"
    implementation("com.squareup.wire:wire-grpc-client:5.3.1")
    implementation 'io.grpc:grpc-okhttp:1.64.0'
    implementation 'io.grpc:grpc-protobuf-lite:1.64.0'
    implementation 'io.grpc:grpc-stub:1.64.0'
}
```

---

## 八、构建命令

### 本地构建命令

```bash
# 安装依赖
flutter pub get

# 生成代码 (如 freezed, json_serializable 等)
dart run build_runner build --delete-conflicting-outputs

# Android APK Debug 构建
flutter build apk --debug

# Android APK Release 构建
flutter build apk --release

# Android AAB 构建 (Google Play)
flutter build appbundle --release

# 运行测试
flutter test

# Linux 构建
flutter build linux --release

# macOS 构建
flutter build macos --release

# Windows 构建
flutter build windows --release
```

### Makefile 目标

```bash
# 查看所有可用的 make 目标
make help

# Android
make android-apk-install-deps
make android-apk-prepare
make android-apk-release

# Linux
make linux-amd64-install-deps
make linux-amd64-prepare
make linux-amd64-release

# Windows
make windows-install-deps
make windows-prepare
make windows-release
```

---

## 九、环境变量

### 必需的环境变量

```bash
# Android SDK
export ANDROID_HOME=/usr/local/lib/android/sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/36.0.0

# Java
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin

# Flutter (如果手动安装)
export PATH=$PATH:/path/to/flutter/bin

# 可选: 用于发布
export SENTRY_DSN=your_sentry_dsn_here
```

### GitHub Actions 环境变量 (CI)

```yaml
env:
  IS_GITHUB_ACTIONS: 1
  FLUTTER_VERSION: '3.38.5'
  NDK_VERSION: r28c
  CHANNEL: "dev"  # 或 "prod"
```

---

## 十、GitHub Actions CI/CD 配置

### 构建矩阵

```yaml
strategy:
  matrix:
    include:
      - platform: android-apk
        os: ubuntu-latest
        targets: apk
      - platform: android-aab
        os: ubuntu-latest
        targets: aab
      - platform: windows
        os: windows-latest
        targets: exe,msix,zip
      - platform: linux
        os: ubuntu-22.04
        targets: deb,gz,AppImage
      - platform: macos
        os: macos-15
        targets: dmg,pkg
```

### Android 构建环境 (CI)

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2.21.0
  with:
    flutter-version: '3.38.5'
    channel: 'stable'
    cache: true

- name: Setup Java
  uses: actions/setup-java@v5
  with:
    distribution: 'zulu'
    java-version: 17

- name: Setup Android SDK
  uses: android-actions/setup-android@v3
```

---

## 十一、签名配置

### Release 签名密钥属性

```properties
# android/key.properties
storePassword=hiddify123456
keyPassword=hiddify123456
keyAlias=hiddify-release
storeFile=release.keystore.jks
```

### 生成签名密钥

```bash
keytool -genkeypair -v -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 \
  -keystore release.keystore.jks \
  -alias hiddify-release \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=hiddify, OU=hiddify, O=hiddify, L=Beijing, ST=Beijing, C=CN"
```

### GitHub Secrets 配置

| Secret Name | Description |
|-------------|-------------|
| `ANDROID_SIGNING_KEY` | Base64 编码的 .jks 文件 |
| `ANDROID_SIGNING_KEY_ALIAS` | 密钥别名 |
| `ANDROID_SIGNING_STORE_PASSWORD` | 密钥库密码 |
| `ANDROID_SIGNING_KEY_PASSWORD` | 密钥密码 |

---

## 十二、常见问题排查

### 1. Flutter 版本不匹配

```
Error: The Flutter SDK version is incompatible with the project.
```

**解决方案**: 确保 Flutter 版本 >= 3.38.5

### 2. Java 版本错误

```
Error: compileSdkVersion 36 requires Java 17 or higher.
```

**解决方案**: 确保 JAVA_HOME 指向 JDK 17

### 3. Android SDK 未找到

```
Error: Android SDK not found. Define location with ANDROID_HOME.
```

**解决方案**: 设置 ANDROID_HOME 环境变量

### 4. NDK 版本不匹配

```
Error: NDK version 28.2.13676358 is not installed.
```

**解决方案**: 使用 sdkmanager 安装对应 NDK 版本

### 5. Gradle 构建缓存问题

```bash
# 清理缓存
flutter clean
rm -rf ~/.gradle/caches
rm -rf build/
flutter pub get
```

---

## 十三、快速开始检查清单

- [ ] Flutter 3.38.5+ 已安装
- [ ] Dart SDK ^3.10.4 可用
- [ ] Java 17+ 已安装
- [ ] ANDROID_HOME 环境变量已设置
- [ ] Android SDK platform-36 已安装
- [ ] NDK 28.2.13676358 已安装
- [ ] Android Build Tools 36.0.0 已安装
- [ ] flutter pub get 已执行
- [ ] 代码生成已运行 (dart run build_runner build)

---

## 附录 A: 完整版本信息表

| 组件 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.38.5 | 跨平台 UI 框架 |
| Dart | 3.x (bundled) | 编程语言 |
| Android SDK | 36 | Android 平台编译 |
| Android Gradle Plugin | 8.6.0 | Gradle 构建插件 |
| Kotlin | 2.1.0 | Android 开发语言 |
| Java | 17 | JVM 版本 |
| NDK | 28.2.13676358 | 原生 C/C++ 编译 |
| CMake | 3.22.1 | NDK 构建工具 |
| Protocol Buffers | 2.0.0 / 0.9.4 | 序列化协议 |
| gRPC | 1.64.0 / 4.0.1 | RPC 框架 |

---

## 附录 B: 本地开发推荐环境 (Ubuntu 22.04)

```bash
# 1. 安装系统依赖
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

# 2. 安装 Flutter
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.5-stable.tar.xz
tar xf flutter_linux_3.38.5-stable.tar.xz
export PATH="$PATH:/path/to/flutter/bin"

# 3. 配置 Android SDK
export ANDROID_HOME=/usr/local/lib/android/sdk
mkdir -p $ANDROID_HOME/cmdline-tools
cd $ANDROID_HOME/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest

# 4. 安装 Android SDK 组件
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
yes | sdkmanager --licenses
sdkmanager "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" "cmake;3.22.1"

# 5. 验证安装
flutter doctor
```
