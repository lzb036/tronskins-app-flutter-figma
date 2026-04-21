# flutter_app 启动步骤
> adb connect 127.0.0.1:7555    链接设备
> flutter run

---

## 修改应用名称

修改 Flutter 应用名称需要同时修改 Android 和 iOS 两端的配置文件。

### Android

文件路径：`android/app/src/main/AndroidManifest.xml`

找到 `<application>` 标签的 `android:label` 属性，修改为新名称：

```xml
<application
    android:label="新应用名称"
    ...>
```

### iOS

文件路径：`ios/Runner/Info.plist`

找到 `CFBundleDisplayName`（展示名）和 `CFBundleName`（包名），修改对应值：

```xml
<key>CFBundleDisplayName</key>
<string>新应用名称</string>
<key>CFBundleName</key>
<string>新应用名称</string>
```

> 修改完成后重新运行 `flutter run` 或重新打包即可生效。

---

## 修改应用图标（flutter_launcher_icons）

### 1. 添加依赖

在 `pubspec.yaml` 的 `dev_dependencies` 中添加：

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3
```

### 2. 配置图标

在 `pubspec.yaml` 末尾添加配置节（或单独创建 `flutter_launcher_icons.yaml`）：

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo.png"        # 图标源文件，建议 1024×1024 PNG，无圆角
  min_sdk_android: 21                  # Android 最低 SDK 版本
  adaptive_icon_background: "#FFFFFF"  # Android 自适应图标背景色
  adaptive_icon_foreground: "assets/logo.png"  # Android 自适应图标前景
```

> 图标源文件已存放于 `assets/logo.png`，直接替换该文件即可。

### 3. 安装依赖并生成图标

```bash
flutter pub get
dart run flutter_launcher_icons
```

执行后会自动覆盖 Android 和 iOS 的所有尺寸图标，无需手动处理。

### 4. 验证

重新运行 `flutter run`，在设备桌面确认图标已更新。

> iOS 模拟器有时需要卸载旧应用再重新安装才能刷新图标缓存。