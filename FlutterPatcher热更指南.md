# FlutterPatcher 热更指南

> 适用范围：TronSkins Android App。
> 目标读者：产品、运营、测试、开发、项目负责人。
> 当前状态：项目已接入 `flutter_patcher`，并作为当前 App 启动时实际使用的热更入口。

## 1. 这份文档要解决什么问题

`flutter_patcher` 是一种 Android 自托管热更新方案。

它更接近 uni-app 的热更思路：

```text
手动生成热更包
  -> 上传到自己的服务器或 CDN
  -> 数据库记录补丁版本
  -> App 启动时请求接口
  -> 如果有新补丁，App 下载并安装
  -> 用户下次冷启动后生效
```

它不依赖 Shorebird 官方服务器，补丁下载地址完全由我们自己控制。

## 2. 简单理解

Flutter Android release 包里的 Dart 代码最终会编译进 `libapp.so`。

`flutter_patcher` 的热更方式就是：

```text
把新的 libapp.so 下载到本地
  -> 校验文件
  -> 保存成补丁
  -> 下次冷启动时优先加载这个补丁
```

所以它不是运行中立即生效，而是 **下载完成后，下次完全关闭并重新打开 App 生效**。

## 3. 当前项目状态

项目中现在保留了三套相关代码：

| 方案 | 当前状态 | 说明 |
|---|---|---|
| `flutter_patcher` | 正在使用 | 当前 App 启动时实际运行的热更方案 |
| Shorebird 官方热更 | 保留但未作为入口使用 | 代码仍在，后续可回退或对比 |
| 多元降级热更模块 | 保留但未使用 | 未来用于 Shorebird 网关/CDN 调度 |

当前实际入口：

- `main.dart` 中调用 `FlutterPatcher.init()`
- App 外层使用 `FlutterPatcherUpdateGate`
- `ShorebirdUpdateGate` 文件仍保留，但不再挂到启动树上

## 4. 当前已接入的客户端文件

| 文件 | 作用 |
|---|---|
| `pubspec.yaml` | 已添加 `flutter_patcher: 0.1.2` |
| `lib/main.dart` | 启动时初始化 `FlutterPatcher`，并使用新的热更入口 |
| `lib/common/widgets/flutter_patcher_update_gate.dart` | 当前实际使用的热更检查、下载、安装、提示入口 |
| `lib/common/widgets/shorebird_update_gate.dart` | Shorebird 旧入口，保留但未使用 |
| `lib/common/hot_update/` | 多元降级热更备用模块，保留但未使用 |

Android 配置也已按 `flutter_patcher` 要求调整：

| 配置项 | 当前值 |
|---|---|
| `minSdk` | `24` |
| `compileSdk` | `36` |
| `ndkVersion` | `27.0.12077973` |
| Java | `17` |
| AGP | `8.11.1` |
| Kotlin | `2.2.20` |
| Gradle | `8.14` |

## 5. App 当前热更流程

用户打开 App 后：

1. `FlutterPatcher.init()` 初始化补丁加载和崩溃保护
2. `FlutterPatcherUpdateGate` 开始检查热更
3. App 请求服务端检查接口
4. 如果没有补丁，继续正常使用
5. 如果有补丁，下载 `libapp.so`
6. 校验成功后安装补丁
7. App 提示用户完全关闭后重新打开
8. 用户下次冷启动后，补丁生效

当前客户端检查接口路径：

```text
api/public/app/flutter-patcher/check
```

完整地址基于当前 App 选择的服务器，例如：

```text
https://www.etopmarket.com/api/public/app/flutter-patcher/check
```

## 6. App 请求服务端时会带什么参数

客户端会通过 query 参数传给服务端：

| 参数 | 说明 |
|---|---|
| `platform` | 固定为 `android` |
| `app_version` | App 基础版本，例如 `1.0.1+1` |
| `version_code` | Android versionCode，例如 `1` |
| `abi` | 当前设备 ABI，例如 `arm64-v8a` |
| `current_patch` | 当前已安装的补丁版本，没有则不传 |
| `device_id` | 本地生成的设备 ID，用于灰度分流 |

示例：

```text
GET /api/public/app/flutter-patcher/check
  ?platform=android
  &app_version=1.0.1+1
  &version_code=1
  &abi=arm64-v8a
  &device_id=xxxx
```

## 7. 服务端应该返回什么

### 7.1 没有更新

```json
{
  "hasUpdate": false
}
```

### 7.2 有更新

```json
{
  "hasUpdate": true,
  "patch": {
    "version": "1.0.1-hotfix.1",
    "patchUrl": "https://patch.tronskins.com/android/1.0.1_1/arm64-v8a/1.0.1-hotfix.1/libapp.so",
    "md5": "0123456789abcdef0123456789abcdef",
    "targetVersionCode": 1,
    "signature": ""
  }
}
```

字段说明：

| 字段 | 必填 | 说明 |
|---|---|---|
| `hasUpdate` | 是 | 是否有热更 |
| `patch.version` | 是 | 补丁版本号，用于判断是否重复安装 |
| `patch.patchUrl` | 是 | `libapp.so` 下载地址 |
| `patch.md5` | 强烈建议 | 补丁文件 MD5，小写 32 位 hex |
| `patch.targetVersionCode` | 强烈建议 | 补丁对应的基础 APK versionCode |
| `patch.signature` | 可选 | Ed25519 签名；暂时不用可传空字符串 |

注意：

- `targetVersionCode` 必须对应用户已安装 APK 的 `versionCode`
- `patchUrl` 必须能被 App 直接访问
- 生产环境必须使用 HTTPS
- 不要给错误 ABI 的设备下发补丁

## 8. 服务端数据库建议

建议至少保存这些字段：

| 字段 | 说明 |
|---|---|
| `app_version` | App 版本名，例如 `1.0.1+1` |
| `version_code` | Android versionCode |
| `patch_version` | 补丁版本，例如 `1.0.1-hotfix.1` |
| `abi` | `arm64-v8a`、`armeabi-v7a`、`x86_64` |
| `patch_url` | `libapp.so` 下载地址 |
| `md5` | 文件 MD5 |
| `signature` | 签名，可先为空 |
| `status` | `staging`、`active`、`paused`、`rollback` |
| `gray_percent` | 灰度比例 |
| `wifi_only` | 是否仅 Wi-Fi 下载 |
| `created_at` | 创建时间 |

只有 `active` 状态的补丁才允许下发。

## 9. 生成热更包流程

### 9.0 手动打包简版

以当前基础版本 `1.0.1+1` 为例：

- `app_version` 是 `1.0.1+1`
- Android `versionCode` 是 `1`
- 补丁版本可以命名为 `1.0.1-hotfix.1`

简化流程如下：

1. 只修改 Flutter Dart 层代码。
2. 不修改 Android 原生代码、插件、assets、`pubspec.yaml` 版本号。
3. 重新构建 release APK。
4. 从 release APK 中打出 `libapp.so` 热更包。
5. 上传 `libapp.so` 到服务器或 CDN。
6. 服务端接口返回 `version`、`patchUrl`，建议同时返回 `md5` 和 `targetVersionCode`。
7. 用户打开 App 后会自动检查、下载、安装补丁。
8. 用户完全关闭并重新打开 App 后，热更生效。

常用命令：

```powershell
flutter pub get

flutter build apk --release `
  --build-name=1.0.1 `
  --build-number=1

dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.1-hotfix.1 `
  --target-version-code 1 `
  --abi arm64-v8a `
  --out dist/flutter_patcher/android/1.0.1_1/arm64-v8a/1.0.1-hotfix.1
```

生成后的核心文件：（**正常到这一步，然后直接把libapp.so文件也就是热更包分发了就行**）

```text
dist/flutter_patcher/android/1.0.1_1/arm64-v8a/1.0.1-hotfix.1/libapp.so
```

计算 MD5：

```powershell
(Get-FileHash .\dist\flutter_patcher\android\1.0.1_1\arm64-v8a\1.0.1-hotfix.1\libapp.so -Algorithm MD5).Hash.ToLower()
```

如果需要兼容 32 位设备，再额外打 `armeabi-v7a`：

```powershell
dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.1-hotfix.1 `
  --target-version-code 1 `
  --abi armeabi-v7a `
  --out dist/flutter_patcher/android/1.0.1_1/armeabi-v7a/1.0.1-hotfix.1
```

最关键的是：`--target-version-code` 必须等于用户当前安装包的 `versionCode`。

### 9.1 正常发正式 APK

先构建正常发布包：

```powershell
flutter build apk --release
```

当前基础版本来自 `pubspec.yaml`：

```yaml
version: 1.0.1+1
```

其中 `+1` 就是 Android `versionCode = 1`。

### 9.2 修改 Dart 代码

只能修改 Flutter Dart 层代码，例如：

- 页面逻辑
- 业务判断
- 文案
- 纯 Dart 工具类
- Widget 布局

不要在热更中修改：

- Android 原生代码
- AndroidManifest
- 图片、字体、JSON 等 assets
- 原生插件
- Flutter Engine
- `pubspec.yaml` 中的资源配置

### 9.3 重新构建 release APK

修改 Dart 后重新构建：

```powershell
flutter build apk --release
```

### 9.4 生成补丁文件

执行：

```powershell
dart run flutter_patcher:pack `
  --apk build/app/outputs/flutter-apk/app-release.apk `
  --version 1.0.1-hotfix.1 `
  --target-version-code 1
```

说明：

- `--version` 是补丁版本号
- `--target-version-code` 是用户当前已安装 APK 的 versionCode
- 这里的 `1` 对应 `pubspec.yaml` 里的 `1.0.1+1`

输出目录：

```text
dist/
  libapp.so
  manifest.json
```

## 10. 上传补丁流程

生成补丁后：

1. 上传 `dist/libapp.so` 到服务器或 CDN
2. 保存 `dist/manifest.json` 备用
3. 计算并记录 `libapp.so` 的 MD5
4. 在数据库新增补丁记录
5. 设置状态为 `staging`
6. 内部测试通过后改成 `active`

推荐 CDN 路径：

```text
/flutter-patcher/android/{app_version}/{version_code}/{abi}/{patch_version}/libapp.so
```

示例：

```text
https://patch.tronskins.com/flutter-patcher/android/1.0.1_1/1/arm64-v8a/1.0.1-hotfix.1/libapp.so
```

## 11. 灰度发布建议

不要直接全量。

建议节奏：

```text
内部测试
  -> 1%
  -> 10%
  -> 50%
  -> 100%
```

每一步观察：

- 热更检查成功率
- 补丁下载成功率
- App 崩溃率
- 用户反馈
- 启动失败或自动回滚日志

## 12. 回滚和暂停

如果补丁有问题：

1. 服务端把补丁状态改成 `paused`
2. 检查接口返回 `hasUpdate: false`
3. 已下载但未重启的用户不会再重复下载
4. 已经安装且出问题的补丁，`flutter_patcher` 会尝试自动回滚并加入本地黑名单

手动回滚能力也存在：

```dart
await FlutterPatcher.rollback();
```

当前项目暂未暴露手动回滚按钮，主要依赖服务端暂停和插件自身的崩溃保护。

## 13. 本地验证命令

建议先设置国内镜像：

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

拉依赖：

```powershell
flutter pub get
```

验证 Dart：

```powershell
flutter analyze lib/main.dart lib/common/widgets/flutter_patcher_update_gate.dart lib/common/hot_update
```

验证插件 Kotlin 编译：

```powershell
cd android
.\gradlew.bat :flutter_patcher:compileDebugKotlin --stacktrace --no-daemon --console=plain
cd ..
```

构建 APK：

```powershell
flutter build apk --debug
```

或：

```powershell
flutter build apk --release
```

如果构建时访问 `storage.googleapis.com` 失败，先确认已经设置：

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

## 14. 真机验收标准

正式使用前，至少验证：

- 首次安装 App 能正常启动
- App 会请求 `api/public/app/flutter-patcher/check`
- 服务端返回 `hasUpdate: false` 时 App 正常使用
- 服务端返回补丁时 App 能下载
- 下载完成后出现重启提示
- 完全关闭并重新打开 App 后补丁生效
- 错误 MD5 时补丁不会被安装
- 下发错误 `targetVersionCode` 时补丁不会生效
- 服务端暂停补丁后，新用户不会继续下载

## 15. 风险说明

| 风险 | 说明 | 应对方式 |
|---|---|---|
| 只支持 Android | iOS 不能使用这种方式 | iOS 仍走正常发版 |
| 只能更新 Dart 代码 | 原生、assets、插件不能热更 | 超出范围必须发新版 |
| 需要冷启动生效 | 不是运行中立即替换 | 下载完成后提示用户重启 |
| 补丁和 APK 强绑定 | versionCode 不匹配会失效 | 服务端严格按 versionCode 下发 |
| 多 ABI 管理复杂 | 不同 ABI 需要对应补丁 | 服务端按 ABI 下发 |
| 渠道合规风险 | 某些应用市场限制下载可执行代码 | 上线前确认渠道规则 |
| 插件仍是 beta | 需要充分真机测试 | 先小流量灰度 |

## 16. 和其他热更方案的关系

| 方案 | 当前状态 | 作用 |
|---|---|---|
| `flutter_patcher` | 当前使用 | 自托管 Android 热更 |
| Shorebird | 保留 | 后续可作为备用方案 |
| 多元降级热更 | 保留 | 后续可做 Shorebird CDN 调度 |

当前不要删除 Shorebird 和多元降级代码，先保留，方便后续回退或对比。

## 17. 参考资料

- `flutter_patcher` pub.dev：https://pub.dev/packages/flutter_patcher
- `flutter_patcher` API 文档：https://pub.dev/documentation/flutter_patcher/latest/topics/API-reference-topic.html
- `flutter_patcher` 架构说明：https://pub.dev/documentation/flutter_patcher/latest/topics/Architecture-topic.html

## 18. 最终建议

短期目标：

1. 服务端先实现 `api/public/app/flutter-patcher/check`
2. CDN 先支持手动上传 `libapp.so`
3. 数据库先支持补丁开关和灰度比例
4. 用 Android 真机跑通一条完整热更链路

完整链路跑通后，再补：

- 后台管理页面
- 一键暂停
- 自动计算 MD5
- 自动上传 CDN
- 自动灰度
- 崩溃率监控
