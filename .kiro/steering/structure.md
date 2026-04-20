---
inclusion: always
---

# 项目结构

## 目录结构

```
lib/
├── api/                        # Dio API 调用函数 + 响应模型
│   ├── market.dart
│   ├── wallet.dart
│   └── model/                  # API 响应模型（按域分子目录）
│       ├── market/
│       └── wallet/
├── bindings/                   # GetX Bindings（路由级 DI 注入）
│   ├── market/market_binding.dart
│   └── wallet/wallet_binding.dart
├── common/                     # 与功能无关的共享基础设施
│   ├── http/                   # HttpHelper 单例 + 拦截器链
│   ├── storage/                # 类型化 GetStorage 封装
│   ├── theme/                  # AppColors、AppTextTheme、亮/暗主题、app_spacing.dart
│   ├── security/               # SM2/SM4 加密、SecureStorage
│   ├── utils/                  # 无状态工具函数
│   ├── widgets/                # 真正通用 Widget（对话框、浮层、按钮等）
│   ├── hooks/                  # 全局永久控制器
│   │   ├── game/               # GlobalGameController
│   │   ├── currency/           # CurrencyController
│   │   ├── theme/              # UseTheme
│   │   └── locale/             # UseLocale
│   └── events/                 # 全局事件总线
├── components/                 # 按功能域划分的可复用组合 Widget（非完整页面）
│   ├── market/
│   ├── game_item/              # 品质/磨损度/贴纸展示组件（禁止在页面层重复实现）
│   └── filter/
├── controllers/                # GetX 控制器（业务逻辑）
│   ├── market/
│   ├── wallet/
│   └── ...（按功能域分子目录）
├── l10n/                       # 多语言翻译（17 种语言）
│   ├── app_translations.dart
│   └── locale/{lang_CODE}/app_i18n.dart
├── pages/                      # 页面/屏幕 Widget（每目录对应一条路由）
│   ├── market/
│   ├── wallet/
│   └── navbar/
├── routes/
│   ├── app_routes.dart         # Routers 类，静态字符串路由常量
│   └── index.dart              # RoutersConfig.list → List<GetPage>
└── main.dart                   # 应用入口，注册全局控制器
```

## 目录职责

### `lib/api/`
- 只包含 Dio 请求函数，禁止包含 UI 或状态逻辑
- 响应模型放 `lib/api/model/<domain>/`，使用 `json_serializable` 生成 `.g.dart`

### `lib/bindings/`
- 每个路由对应一个 `XxxBinding extends Bindings`
- **只能**通过 `Get.lazyPut` 注册控制器，禁止 `Get.put`

### `lib/common/`
- 纯基础设施，**不绑定任何业务功能**
- `storage/`：禁止在页面或控制器中直接调用原始 `GetStorage`
- `http/`：拦截器链顺序固定 `Header → Auth → Cookie → Logging`
- `hooks/`：全局永久控制器，在 `main()` 中 `Get.put(..., permanent: true)` 注册，禁止在其他地方重复注册

### `lib/components/`
组件层级划分：

| 层级 | 位置 | 适用场景 |
|------|------|----------|
| 真正通用 Widget | `lib/common/widgets/` | 对话框、Toast、按钮等，无业务含义 |
| 功能域组合组件 | `lib/components/<domain>/` | 跨页面复用但绑定特定业务域 |
| 页面级私有组件 | `lib/pages/<feature>/_widgets/` | 仅在单个页面内使用 |

- 组件文件不超过 **300 行**，`build()` 超过 **80 行**必须拆分
- 禁止在组件中直接调用 API 或持有 `GetxController` 实例
- 禁止在组件中直接格式化金额，通过 `CurrencyController` 处理后传入

### `lib/controllers/`
- 每个逻辑关注点一个控制器，继承 `GetxController`
- 响应式状态用 `.obs`，**禁止**持有 Widget 引用
- 通过构造函数注入 API 依赖，便于测试

### `lib/pages/`
- 页面保持"薄"：只读取控制器数据、响应用户事件，**不含业务逻辑**
- 每个目录对应一条路由

### `lib/routes/`
- `app_routes.dart`：`Routers` 类，路由常量 `SCREAMING_SNAKE_CASE`，路径 `kebab-case`
- `index.dart`：`RoutersConfig.list` 返回 `List<GetPage>`，附带 binding 和转场动画
- 禁止在页面或控制器中硬编码路由路径，必须使用 `Routers.XXX` 常量
- 禁止跳过 `RoutersConfig.list` 直接使用 `Get.to(() => SomePage())`

## 新功能开发检查清单

新增一个功能模块，必须同时包含以下文件：

| 文件 | 路径示例 | 说明 |
|------|----------|------|
| 页面 Widget | `lib/pages/feature/feature_page.dart` | 薄页面，只读数据 |
| 控制器 | `lib/controllers/feature/feature_controller.dart` | 业务逻辑 |
| Binding | `lib/bindings/feature/feature_binding.dart` | DI 注入 |
| 路由条目 | `lib/routes/index.dart` | 注册 GetPage |
| 路由常量 | `lib/routes/app_routes.dart` | 添加 `Routers.FEATURE` |
| API 文件 | `lib/api/feature.dart` | Dio 请求函数 |

缺少任何一项均视为不完整实现。

## 禁止事项

- 禁止在 `lib/` 根目录下新建非标准目录
- 禁止将业务逻辑写在 `lib/common/` 中
- 禁止在 `lib/api/` 中引用 Widget 或 GetX 控制器
- 禁止跨功能域直接引用另一个域的控制器（通过事件总线 `lib/common/events/` 通信）
- 禁止在页面层直接调用 `GetStorage`、格式化金额、硬编码 UI 字符串
- 禁止硬编码颜色值、`TextStyle`、间距魔法数字
