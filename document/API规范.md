---
alwaysApply: false
description: 接口请求封装、函数命名、模型定义、错误处理规范。新增或修改接口时读取。
---

# API 规范

## 接口文件组织

- 每个业务域一个文件，放在 `lib/api/<domain>.dart`
- 响应模型放在 `lib/api/model/<domain>/`，使用 `json_serializable` 生成 `.g.dart`
- 所有请求通过单例 `HttpHelper` 发起，**禁止**在 API 文件中直接创建 `Dio` 实例

```
lib/api/
├── market.dart           # 市场相关接口
├── wallet.dart           # 钱包相关接口
├── shop.dart             # 商店相关接口
├── user.dart             # 用户相关接口
└── model/
    ├── market/
    │   ├── market_item.dart
    │   └── market_item.g.dart
    └── wallet/
        ├── wallet_record.dart
        └── wallet_record.g.dart
```

## 接口函数命名（NON-NEGOTIABLE）

| 操作 | 命名规则 | 示例 |
|------|----------|------|
| 获取列表 | `getXxxList` | `getMarketItemList` |
| 获取详情 | `getXxxDetail` | `getMarketItemDetail` |
| 创建资源 | `createXxx` | `createShopListing` |
| 更新资源 | `updateXxx` | `updateItemPrice` |
| 删除资源 | `deleteXxx` | `deleteShopListing` |
| 提交操作 | `submitXxx` | `submitWithdrawal` |
| 上传文件 | `uploadXxx` | `uploadAvatar` |

**禁止**使用 `fetch`、`request`、`doXxx` 等模糊前缀。

## 接口函数规范

```dart
/// 获取市场物品列表
///
/// [params] 筛选和分页参数
Future<List<MarketItem>> getMarketItemList(MarketListParams params) async {
  final response = await HttpHelper.instance.get(
    '/market/items',
    queryParameters: params.toJson(),
  );
  return (response.data['list'] as List)
      .map((e) => MarketItem.fromJson(e))
      .toList();
}

/// 获取市场物品详情
///
/// [itemId] 物品 ID
Future<MarketItemDetail> getMarketItemDetail(String itemId) async {
  final response = await HttpHelper.instance.get('/market/items/$itemId');
  return MarketItemDetail.fromJson(response.data);
}

/// 创建挂单
Future<void> createShopListing(CreateListingBody body) async {
  await HttpHelper.instance.post('/shop/listings', data: body.toJson());
}
```

## 请求参数与响应模型

- 请求参数（Query/Body）定义为独立类，命名：`XxxParams`（Query）、`XxxBody`（Body）
- 响应模型命名：`XxxModel` 或语义名（如 `MarketItem`、`WalletRecord`）
- 所有模型使用 `@JsonSerializable()` 注解，生成 `.g.dart`
- 修改模型后必须重新运行 `dart run build_runner build --delete-conflicting-outputs`

```dart
/// 市场列表查询参数
@JsonSerializable()
class MarketListParams {
  /// 游戏 appId
  final String appId;

  /// 页码，从 1 开始
  final int page;

  /// 每页数量
  final int pageSize;

  /// 排序字段
  final String? sortBy;

  const MarketListParams({
    required this.appId,
    this.page = 1,
    this.pageSize = 20,
    this.sortBy,
  });

  Map<String, dynamic> toJson() => _$MarketListParamsToJson(this);
}
```

## 多游戏参数（NON-NEGOTIABLE）

所有涉及游戏数据的接口必须携带 `appId` 参数，通过 `GlobalGameController` 获取：

```dart
/// 控制器中调用示例
Future<void> fetchMarketList() async {
  final appId = Get.find<GlobalGameController>().currentAppId;
  final result = await getMarketItemList(
    MarketListParams(appId: appId, page: _page),
  );
  items.assignAll(result);
}
```

**禁止**在 API 函数内部直接调用 `GlobalGameController`，appId 由调用方（控制器）传入。

## 错误处理（NON-NEGOTIABLE）

- 通用错误（网络超时、401、500 等）由 `HttpHelper` 拦截器统一处理
- 业务代码**只处理成功逻辑**，不重复弹出错误提示
- 需要特殊处理的业务错误码，在控制器层 `try/catch` 捕获后处理

```dart
// ✅ 正确：控制器只处理成功逻辑
Future<void> fetchMarketList() async {
  try {
    isLoading.value = true;
    items.assignAll(await getMarketItemList(params));
  } catch (e, s) {
    // 仅记录日志，通用错误已由拦截器处理
    logger.e('获取市场列表失败', error: e, stackTrace: s);
  } finally {
    isLoading.value = false;
  }
}

// ❌ 错误：重复弹出错误提示
Future<void> fetchMarketList() async {
  try {
    items.assignAll(await getMarketItemList(params));
  } catch (e) {
    Get.snackbar('错误', e.toString()); // 拦截器已处理，禁止重复弹出
  }
}
```

## 拦截器链（禁止修改顺序）

```
HeaderInterceptor → AuthInterceptor → CookieInterceptor → LoggingInterceptor
```

- 新增拦截器必须插入到正确位置，不得破坏链顺序
- Steam Session 注入逻辑在 `CookieInterceptor` 中，修改需格外谨慎

## 禁止事项

- 禁止在 API 文件中引用任何 Widget 或 `GetxController`
- 禁止在 API 文件中直接实例化 `Dio`
- 禁止在页面层直接调用 API 函数（必须通过控制器）
- 禁止使用 `fetch`、`request` 等模糊命名前缀
- 禁止在业务代码中重复处理已由拦截器处理的通用错误
