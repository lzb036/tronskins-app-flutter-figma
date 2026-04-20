---
inclusion: always
---

# 技术栈与编码规范

## 框架与语言
- Flutter，Dart SDK `^3.9.2`
- Material 3（`useMaterial3: true`）

## 核心依赖

### 状态管理 & 依赖注入
- `get ^4.6.1` — GetX，负责状态管理、DI 和路由导航
  - 响应式状态用 `.obs`，控制器继承 `GetxController`
  - 全局永久控制器在 `main()` 中 `Get.put(..., permanent: true)` 注册
  - 路由级控制器只通过 `Binding` 的 `Get.lazyPut` 注册，**禁止**在页面中手动 `Get.put`
- `get_storage ^2.0.5` — 轻量本地持久化，命名 box：`language`、`theme`
  - **禁止**在页面或控制器中直接调用原始 `GetStorage`，必须通过 `lib/common/storage/` 的类型化封装

### 网络
- `dio ^5.3.2` — HTTP 客户端，通过单例 `HttpHelper` 使用
  - 拦截器链（顺序固定，禁止修改）：`HeaderInterceptor → AuthInterceptor → CookieInterceptor → LoggingInterceptor`
  - Steam Session 注入逻辑在 `CookieInterceptor` 中，修改需格外谨慎

### 序列化 / 模型
- `json_annotation` + `json_serializable` — JSON 模型，生成 `.g.dart`
- `freezed_annotation` + `freezed` — 不可变模型，生成 `.freezed.dart`
- `equatable` — 值相等比较
- 生成文件（`*.g.dart`、`*.freezed.dart`）**提交到仓库**，修改模型后必须重新生成

### UI 组件
- `cached_network_image` — 远程图片缓存，**禁止**裸 `Image.network`
- `flutter_slidable` — 可滑动列表项
- `flutter_html` — 渲染 HTML 内容
- `fl_chart` — 价格趋势图
- `qr_flutter` / `mobile_scanner` — 二维码展示与扫描
- `webview_flutter` — Steam 登录 WebView（修改需谨慎，涉及 Session 注入）
- `image_picker` — 图片上传

### 安全 & 认证
- `encrypt` + `dart_sm` — SM2/SM4 加密，封装在 `lib/common/security/`
- `local_auth` — 生物识别认证
- `otp` — TOTP/2FA 验证码生成

### 其他
- `intl` — 日期/数字格式化
- `shorebird_code_push` — OTA 热更新
- `restart_app` — 完整应用重启
- `path_provider` — 文件系统路径
- `logger` — 结构化日志，描述信息使用中文

## 代码生成

修改任何使用 `json_serializable` 或 `freezed` 的模型后，必须重新运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 常用命令

```bash
flutter pub get                   # 安装依赖
flutter run                       # 调试运行
flutter build apk                 # Android release APK
flutter build ios                 # iOS release 构建
flutter analyze                   # 静态分析（flutter_lints）零警告才算通过
flutter test                      # 运行所有测试
shorebird release android         # 发布 OTA 补丁（Android）
shorebird release ios             # 发布 OTA 补丁（iOS）
```

## Dart 编码规范

- 遵循 `flutter_lints` 规则，`flutter analyze` 零警告
- 禁止使用 `dynamic`（除非有明确理由并附注释）
- 优先使用 `const` 构造函数，减少不必要的 Widget 重建
- 禁止在 `build()` 方法中执行业务逻辑或网络请求
- 禁止空 `catch` 块，至少记录日志：`logger.e('描述', error: e, stackTrace: s)`
- 禁止直接 `print`，用户可见错误通过 `Get.snackbar` 或统一 Toast 展示

## 命名规范

| 类型 | 规则 | 示例 |
|------|------|------|
| 文件 / 目录 | `snake_case` | `market_detail_page.dart` |
| 变量 / 函数 | `camelCase` | `itemList`, `fetchData` |
| 常量 | `camelCase` | `apiTimeout`, `maxRetryCount` |
| 类 / 枚举 | `PascalCase` | `MarketItem`, `OrderStatus` |
| 控制器 | `FeatureController` | `MarketController` |
| Binding | `FeatureBinding` | `MarketBinding` |
| 页面 Widget | `FeaturePage` | `MarketDetailPage` |
| 路由常量 | `SCREAMING_SNAKE_CASE`（`Routers` 静态成员） | `Routers.MARKET_DETAIL` |
| 响应式变量 | `RxType` + `.obs` | `final count = 0.obs` |
| 私有成员 | `_camelCase` | `_isLoading` |

## 业务函数命名

- UI 回调：`onXxx`（`onSubmit`、`onItemTap`）
- 内部逻辑：`handleXxx`（`handleDelete`）
- 数据获取：`fetchXxx` / `loadXxx`
- 数据提交：`submitXxx` / `saveXxx`
- 状态切换：`toggleXxx`
- 格式化：`formatXxx` / `parseXxx`

## API 规范

- 每个业务域一个文件 `lib/api/<domain>.dart`，只包含 Dio 请求函数
- 响应模型放 `lib/api/model/<domain>/`，使用 `@JsonSerializable()` 注解
- 所有请求通过单例 `HttpHelper` 发起，**禁止**直接实例化 `Dio`
- **禁止**在 API 文件中引用 Widget 或 `GetxController`
- **禁止**在页面层直接调用 API 函数，必须通过控制器

### 接口函数命名（NON-NEGOTIABLE）

| 操作 | 命名 | 示例 |
|------|------|------|
| 获取列表 | `getXxxList` | `getMarketItemList` |
| 获取详情 | `getXxxDetail` | `getMarketItemDetail` |
| 创建 | `createXxx` | `createShopListing` |
| 更新 | `updateXxx` | `updateItemPrice` |
| 删除 | `deleteXxx` | `deleteShopListing` |
| 提交 | `submitXxx` | `submitWithdrawal` |
| 上传 | `uploadXxx` | `uploadAvatar` |

**禁止**使用 `fetch`、`request`、`doXxx` 等模糊前缀。

### 错误处理

- 通用错误（401、500、超时）由拦截器统一处理，业务层**不重复弹出**错误提示
- 控制器只记录日志，特殊业务错误码才在控制器层单独处理

## 样式规范

- 颜色统一通过 `AppColors`（`ThemeExtension`）获取，**禁止硬编码颜色值**
- 字体样式统一通过 `AppTextTheme`（`ThemeExtension`）获取，**禁止硬编码 `TextStyle`**
- 间距常量定义在 `lib/common/theme/app_spacing.dart`（`kSpacingXS/S/M/L/XL/2XL`），**禁止魔法数字**
- AppBar 样式已由 `settingsTopBarAppBarTheme()` 全局统一，页面中**禁止**重复设置 `backgroundColor`、`elevation` 等
- 远程图片统一使用 `CachedNetworkImage`，**禁止**裸 `Image.network`

```dart
// ✅ 正确
final colors = Theme.of(context).extension<AppColors>()!;
final textTheme = Theme.of(context).extension<AppTextTheme>()!;
Text('标题', style: textTheme.titleMedium.copyWith(color: colors.textPrimary))

// ❌ 错误
Text('标题', style: const TextStyle(fontSize: 18, color: Color(0xFF212121)))
```

## 注释规范

- 公开类和方法必须有 `///` 文档注释，使用中文，**禁止** `/** */`
- 复杂逻辑用 `//` 行注释说明意图（解释"为什么"，不重复代码）
- 临时代码用 `// TODO:` / `// FIXME:` 标记，附中文说明
- 单行抑制 lint：`// ignore: rule_name`，**禁止** `// ignore_for_file:`
