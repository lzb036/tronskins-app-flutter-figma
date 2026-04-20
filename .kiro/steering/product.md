---
inclusion: always
---

# Product: TronSkins

TronSkins 是一款面向 CS:GO 皮肤交易的 Flutter 移动端市场应用，连接买家与卖家，深度集成 Steam 进行身份验证和库存管理，支持 Android 和 iOS，通过 Shorebird 实现 OTA 热更新。

## 核心功能模块

| 模块 | 路径 | 说明 |
|------|------|------|
| Marketplace（市场） | `lib/pages/market/` | 浏览、购买、出售皮肤；筛选、排序、价格趋势图 |
| Inventory（库存） | `lib/pages/navbar/inventory.dart` | 查看 Steam 库存，将物品上架到商店 |
| Shop（商店） | `lib/pages/shop/` | 卖家管理挂单、定价、订单、批量购买请求 |
| Wallet（钱包） | `lib/pages/wallet/` | 充值、提现、结算、资金流水、锁定余额 |
| Steam 集成 | `lib/pages/steam/` | WebView 登录、交易链接绑定、Session 注入、2FA/TOTP |
| User（用户） | `lib/pages/user/` | 个人资料、收藏、消息通知、设置 |
| Help Center（帮助中心） | `lib/pages/help/` | FAQ 分类、反馈工单创建与跟踪 |
| Loyalty（积分/优惠） | `lib/pages/integral/`, `lib/pages/coupon/` | 积分系统、优惠券管理、抽奖 |

## 关键全局控制器

以下控制器均在 `main()` 中以 `Get.put(..., permanent: true)` 注册，位于 `lib/common/hooks/`：

| 控制器 | 位置 | 职责 |
|--------|------|------|
| `GlobalGameController` | `hooks/game/` | 管理当前选中游戏（appId），所有 API 请求必须携带 |
| `CurrencyController` | `hooks/currency/` | 统一货币格式化，页面层禁止直接处理金额 |
| `UseTheme` | `hooks/theme/` | 主题切换，持久化到 `GetStorage('theme')` |
| `UseLocale` | `hooks/locale/` | 语言切换，持久化到 `GetStorage('language')` |

### 访问方式

```dart
final game = GlobalGameController.ensureInstance();  // 工厂方法
final currency = CurrencyController.to;              // 静态 getter
final theme = Get.find<UseTheme>();
```

## 本地化

- 支持 17 种语言：`en_US` `zh_CN` `zh_TW` `ja_JP` `ko_KR` `ru_RU` `es_ES` `fr_FR` `de_DE` `it_IT` `pt_PT` `pl_PL` `tr_TR` `th_TH` `vi_VN` `id_ID` `la_LAT`
- 翻译文件：`lib/l10n/locale/{lang_CODE}/app_i18n.dart`
- 所有 UI 字符串必须使用 `'key'.tr`，**禁止硬编码文本**

## 业务规则与约束

### Steam 集成（高风险）
- Session 注入和 2FA/TOTP 逻辑集中在 `lib/pages/steam/` 和 `lib/controllers/auth/`，修改需格外谨慎
- WebView 相关改动可能破坏 Steam 登录流程，需完整回归测试

### 钱包（资金敏感）
- 充值、提现、结算操作必须确保状态一致性
- 相关控制器：`lib/controllers/wallet/`
- 资金相关逻辑必须编写单元测试

### 多游戏支持（NON-NEGOTIABLE）
- 所有涉及游戏数据的控制器必须监听 `GlobalGameController.currentAppId` 变化，切换游戏后刷新数据
- 所有涉及游戏数据的 API 请求必须携带 `appId` 参数，由控制器传入，**禁止**在 API 函数内部读取

### 货币格式化（NON-NEGOTIABLE）
- 统一通过 `CurrencyController` 处理，**禁止**在页面或控制器中直接格式化金额

```dart
// ✅ 正确
Text(CurrencyController.to.format(item.price))

// ❌ 错误
Text('\$${item.price.toStringAsFixed(2)}')
```

### 市场物品展示
- 物品属性（品质 quality、磨损度 wear、贴纸 sticker）的展示组件封装在 `lib/components/game_item/`
- **禁止**在页面层重复实现属性渲染逻辑，直接复用现有组件

### 状态管理关键规则
- 路由级控制器只通过 Binding 的 `Get.lazyPut` 注册，**禁止**在页面中手动 `Get.put`
- Worker 必须在 `onClose()` 中 dispose，防止内存泄漏
- 跨功能域通信通过事件总线 `lib/common/events/`，**禁止**直接 `Get.find` 另一个域的控制器
