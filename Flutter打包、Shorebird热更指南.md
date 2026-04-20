# Flutter 打包 & Shorebird 热更指南

> 适用项目：TronSkins Flutter App（Windows 环境）

---

## 一、环境准备

### 1.1 前置条件

- 已安装 Git
- 已安装 Flutter 环境
- 已注册 Shorebird 账号：https://console.shorebird.dev/

### 1.2 安装 Shorebird CLI（手动安装，适用于网络受限环境）

**方式：克隆仓库手动安装**

```powershell
git clone https://github.com/shorebirdtech/shorebird.git C:\Users\Administrator\shorebird
```

**将 bin 目录加入 PATH（永久生效）：**

```powershell
[Environment]::SetEnvironmentVariable("PATH", [Environment]::GetEnvironmentVariable("PATH", "User") + ";C:\Users\Administrator\shorebird\bin", "User")
```

重新打开 PowerShell 后验证：

```powershell
shorebird --version
```

### 1.3 配置代理（访问 Shorebird 服务必须）

Shorebird 需要访问以下地址，国内需要代理：
- `https://api.shorebird.dev`
- `https://oauth2.googleapis.com`
- `https://cdn.shorebird.cloud`

在 PowerShell 中临时设置代理（每次打开新窗口需重新执行）：

```powershell
$env:HTTPS_PROXY = "http://127.0.0.1:7890"  # 替换为你的代理端口
$env:HTTP_PROXY  = "http://127.0.0.1:7890"
```

常见代理端口：Clash/Clash Verge = `7890`，v2rayN = `10809`，Shadowsocks = `1080`

**永久生效（写入 PowerShell Profile）：**

```powershell
notepad $PROFILE
# 在文件末尾加入上面两行，保存后重开窗口生效
```

### 1.4 登录账号

```powershell
shorebird login
```

会打开浏览器完成 Google 账号授权（需代理）。

### 1.5 修复 Git 长路径问题

```powershell
git config --system core.longpaths true
```

---

## 二、项目初始化（首次使用）

在项目根目录执行：

```powershell
shorebird init
```

完成后会：
- 生成 `shorebird.yaml`（含 `app_id`，可提交 git）
- 自动将 `shorebird.yaml` 加入 `pubspec.yaml` assets

> **注意：** `app_id` 与 Shorebird 账号绑定，不同账号的 `app_id` 不通用。如果报 `Could not find app with id` 错误，需重新执行 `shorebird init`。

运行诊断确认配置正确：

```powershell
shorebird doctor
# 如有可自动修复的问题：
shorebird doctor --fix
```

---

## 三、打包 Release APK

### 3.1 执行打包命令

```powershell
# 打 APK（测试分发用）
shorebird release android --artifact apk

# 打 AAB（上架 Google Play 用）
shorebird release android
```

### 3.2 输出路径

```
build/app/outputs/flutter-apk/app-release.apk
```

### 3.3 注意事项

- 打包前确保 `android/app/src/main/AndroidManifest.xml` 包含网络权限：
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  ```
- 版本号在 `pubspec.yaml` 中设置，格式：`version: 1.0.0+1`（`+` 前为版本名，后为版本号）
- 每次发新版本需修改版本号，否则热更包无法匹配

---

## 四、推送热更包（Patch）

代码修复或功能更新后，无需重新上架，直接推送热更包：

```powershell
# 针对当前版本推送热更
shorebird patch android

# 针对指定版本推送热更
shorebird patch android --release-version=1.0.0+1
```

### 热更限制

| 支持热更 | 不支持热更 |
|---------|-----------|
| Dart 代码修改 | 原生 Android/iOS 代码修改 |
| 资源文件（图片、字体等） | 新增原生插件 |
| pubspec.yaml 中的 assets | AndroidManifest 修改 |

### 热更生效流程（本项目为手动触发模式）

本项目 `shorebird.yaml` 配置了 `auto_update: false`，更新由 `shorebird_code_push` 包手动触发：

1. App 启动后调用 `ShorebirdUpdater` 检查是否有新补丁
2. 有补丁则后台下载
3. 下载完成后自动重启应用（重启失败时提示用户手动重启）

---

## 五、常见问题

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| `shorebird` 命令找不到 | PATH 未配置 | 执行 `$env:PATH += ";C:\Users\Administrator\shorebird\bin"` |
| `Could not find app with id` | app_id 不属于当前账号 | 执行 `shorebird init` 重新初始化 |
| `api.shorebird.dev unreachable` | 网络不通 | 配置代理后重试 |
| `missing the INTERNET permission` | AndroidManifest 缺少权限 | 添加 `INTERNET` 权限或执行 `shorebird doctor --fix` |
| patch 热更不生效 | 版本号不匹配 | 确保 patch 基于对应 release 版本的代码构建 |
| debug 包无法热更 | debug 包不支持 | 必须使用 `shorebird release` 打出的包 |

---

## 六、日常发版流程

```
修改代码
    ↓
更新 pubspec.yaml 版本号（发新版时）
    ↓
shorebird release android --artifact apk   ← 生成安装包
    ↓
安装到设备测试
    ↓
后续 bug 修复 → shorebird patch android    ← 推送热更，无需重新安装
```
