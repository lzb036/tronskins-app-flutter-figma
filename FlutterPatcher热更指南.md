# FlutterPatcher 热更操作指南

适用范围：TronSkins Android App

当前项目已经接入 `flutter_patcher`，并且当前代码链路已经支持：

- App 启动自动检查热更
- 请求热更接口时自动携带 `abi`
- 按服务端返回的 `version` 校验基础包版本
- 下载并安装 `libapp.so`
- 安装成功后自动重启 App

当前基础版本：

```yaml
version: 1.0.3+1
```

也就是：

- `versionName = 1.0.3`
- `versionCode = 1`

---

## 1. 整套热更流程

实际操作时，就按下面这套顺序走：

1. 先准备一个 **release 基础包**
2. 安装这个基础包到测试设备
3. 只修改 Flutter Dart 代码
4. 重新构建 release APK
5. 从 release APK 中打出 `libapp.so`
6. 按设备 ABI 上传对应的补丁文件到服务器
7. 服务端接口返回这份补丁的地址和版本信息
8. App 启动后自动检查、下载、安装补丁
9. App 自动重启后，补丁生效

一句话理解：

```text
release 基础包
  -> 修改 Dart 代码
  -> 打出 libapp.so
  -> 上传服务器
  -> 接口返回补丁信息
  -> App 下载并安装
  -> 重启后生效
```

---

## 2. 当前客户端怎么检查热更

当前客户端请求：

```text
/api/public/app/version/v1/latest/by-app
```

当前固定参数：

- `appKey=tronskins-flutter`
- `platform=android`

客户端还会自动携带：

- `abi=FlutterPatcher.deviceAbi`

常见 ABI：

- 真机：`arm64-v8a`
- 32 位老设备：`armeabi-v7a`
- Android 模拟器：`x86_64`

示例：

```text
GET /api/public/app/version/v1/latest/by-app?appKey=tronskins-flutter&platform=android&abi=x86_64
```

---

## 3. 服务端返回什么

服务端至少要返回这些字段：

```json
{
  "code": 0,
  "statusCode": 200,
  "datas": {
    "flag": true,
    "appKey": "tronskins-flutter",
    "platform": "Android",
    "version": "1.0.3",
    "hotPackage": "https://update.xxx.com/download/tronskins-app/2026051801.so",
    "timestamp": "2026051801"
  }
}
```

字段说明：

- `flag`: 是否启用这次热更
- `version`: 这份补丁对应的基础包版本
- `hotPackage`: `.so` 下载地址
- `timestamp`: 补丁版本号

---

## 4. 热更生效的前提

下面这些条件必须同时满足：

1. 基础包必须是 **release APK**
2. 服务端返回的 `version` 必须和用户当前安装包版本一致
3. 服务端必须返回 `hotPackage`
4. 服务端要按 `abi` 返回对应的 `.so`
5. 基础 APK 和补丁 `.so` 不能是同一份代码内容

例如：

- 用户当前安装的是 `1.0.3+1`
- 那服务端返回就必须是 `version: 1.0.3`

如果版本不一致，客户端会直接跳过补丁。

---

## 5. 哪些改动可以热更

可以热更：

- 页面逻辑
- 业务判断
- 文案
- Widget 布局
- 纯 Dart 工具类

不要走热更：

- Android 原生代码
- 原生插件
- AndroidManifest
- assets
- 图片、字体、JSON
- `pubspec.yaml` 资源配置

---

## 6. 先打 release 基础包

如果只按当前 `pubspec.yaml` 版本走，直接执行：

```powershell
flutter build apk --release `
  --build-name=1.0.3 `
  --build-number=1
```

更省事的做法是直接依赖 `pubspec.yaml`，不手写版本号：

```powershell
flutter build apk --release
```

---

## 7. 打热更包

基础命令：

```powershell
dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.3-hotfix.1 `
  --target-version-code 1 `
  --abi arm64-v8a `
  --out dist/flutter_patcher/android/1.0.3_1/arm64-v8a/1.0.3-hotfix.1
```

这里最关键的参数：

- `--version`: 补丁版本名
- `--target-version-code`: 必须等于用户当前安装包的 `versionCode`
- `--abi`: 当前这份补丁对应的设备架构
- `--out`: 输出目录

---

## 8. 多种 ABI 怎么打

### 8.1 真机常用 `arm64-v8a`

```powershell
dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.3-hotfix.1 `
  --target-version-code 1 `
  --abi arm64-v8a `
  --out dist/flutter_patcher/android/1.0.3_1/arm64-v8a/1.0.3-hotfix.1
```

### 8.2 32 位设备用 `armeabi-v7a`

```powershell
dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.3-hotfix.1 `
  --target-version-code 1 `
  --abi armeabi-v7a `
  --out dist/flutter_patcher/android/1.0.3_1/armeabi-v7a/1.0.3-hotfix.1
```

### 8.3 模拟器测试用 `x86_64`

```powershell
dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.3-hotfix.1 `
  --target-version-code 1 `
  --abi x86_64 `
  --out dist/flutter_patcher/android/1.0.3_1/x86_64/1.0.3-hotfix.1
```

---

## 9. 上传时怎么区分 ABI

建议每种 ABI 单独保存：

```text
dist/flutter_patcher/android/1.0.3_1/arm64-v8a/1.0.3-hotfix.1/libapp.so
dist/flutter_patcher/android/1.0.3_1/armeabi-v7a/1.0.3-hotfix.1/libapp.so
dist/flutter_patcher/android/1.0.3_1/x86_64/1.0.3-hotfix.1/libapp.so
```

服务端应根据客户端传来的 `abi` 返回对应地址。

例如：

- `abi=arm64-v8a` -> 返回真机补丁
- `abi=x86_64` -> 返回模拟器补丁

不同 ABI 的 `.so` 不能混用。

---

## 10. 最常见的失败原因

### 情况 1：下载成功，但界面没变化

优先检查：

- 基础包和补丁是不是同一份代码
- 服务端返回的 `.so` ABI 对不对
- 当前设备 ABI 是不是和补丁 ABI 一致

### 情况 2：接口返回了补丁，但客户端跳过

优先检查：

- 服务端 `version` 和本地基础包版本是否一致

### 情况 3：接口返回成功，但没有开始下载

优先检查：

- 有没有返回 `hotPackage`
- `flag` 是否为 `true`

---

## 11. 推荐测试方式

建议这样测试：

1. 先用旧代码打 release 基础包
2. 安装后确认界面是旧效果
3. 再用新代码打 `.so`
4. 上传到服务器
5. 服务端返回新补丁
6. 启动 App，等它下载安装并自动重启
7. 重启后确认界面变成新效果

不要这样测：

1. 先用新代码打 `.so`
2. 再用同一份新代码打基础 APK

这样即使热更成功，界面也看不出变化。

---

## 12. 最终操作要点

真正要记住的就这几条：

1. 基础包一定要是 **release**
2. 服务端 `version` 一定要和基础包一致
3. 服务端一定要返回 `hotPackage`
4. 一定要按设备 ABI 打对应补丁
5. 真机通常打 `arm64-v8a`
6. 模拟器通常打 `x86_64`
7. 补丁和基础包代码必须有真实差异

如果这几条都满足，当前项目就可以正常走热更。