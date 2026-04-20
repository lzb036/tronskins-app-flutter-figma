# Tronskins Codex Subagents

这份文件是这个仓库的 subagent 使用说明，不是 subagent 的真实配置本体。

按 Codex 官方方式，真正生效的部分在：

- [AGENTS.md](/E:/tronskins/tronskins-app-flutter-figma/AGENTS.md)
- [.codex/config.toml](/E:/tronskins/tronskins-app-flutter-figma/.codex/config.toml)
- `.codex/agents/*.toml`

主线程 agent 才是协调者。自定义 subagents 应该是窄职责、可复用、可并行的专职 agent，而不是把整个项目组织结构机械翻译成一套“静态岗位表”。

## 已配置的自定义 Agents

### `feature_mapper`

用途：

- 只读探索
- 先把路由、页面、控制器、API、共享依赖映射清楚
- 判断当前任务是否适合并行写代码

适合场景：

- 需求刚进来，边界不清楚
- 需要先确认会不会撞到 `main/routes/navbar/filter/common hooks`
- 要找真实入口文件和共享依赖

### `getx_reviewer`

用途：

- 只读审查 `GetX` 风险
- 检查 `Get.put / Get.find / Bindings / Worker / permanent` 等生命周期问题
- 查跨页面刷新、全局状态、隐式依赖带来的回归风险

适合场景：

- 改登录态、路由注入、tab 切换、语言/汇率传播
- 改 controller 生命周期
- 做 PR 风险审查

### `market_shop_worker`

用途：

- 负责 `market / shop / inventory` 主业务实现
- 只在分配范围内做最小可辩护改动

适合场景：

- 市场、库存、售卖、订单、卖家店铺、列表/详情修复

### `account_wallet_worker`

用途：

- 负责 `auth / steam / user / wallet / help / system` 业务实现
- 避免随意碰共享初始化和导航层

适合场景：

- 登录、Steam、用户中心、钱包、帮助中心、系统设置

### `test_guard`

用途：

- 跑 `flutter analyze`
- 跑测试
- 补最小范围测试
- 汇总未验证风险

适合场景：

- 任意实现任务收尾
- 回归检查
- 为薄弱区域补 controller 级测试

## 推荐用法

### 1. 先映射，再动手

复杂任务先用：

- `feature_mapper`
- 必要时并行加一个 `getx_reviewer`

等两者返回后，再决定是否交给写代码 worker。

### 2. 写代码时只开一个写入 worker

默认不要同时开多个写入型 subagent 改同一个功能域。

推荐模式：

- `feature_mapper` 和 `getx_reviewer` 并行
- `market_shop_worker` 或 `account_wallet_worker` 二选一执行实现
- `test_guard` 最后验证

### 3. 共享热点默认只让主线程决定

以下区域不要让业务 worker 自己扩边界：

- `lib/main.dart`
- `lib/routes/**`
- `lib/bindings/**`
- `lib/components/layout/navbar/**`
- `lib/common/hooks/**`
- `lib/components/filter/**`
- `lib/controllers/user/user_controller.dart`

如果 worker 认为必须改这些文件，应该先返回给主线程说明原因，再由主线程决定是否接手或重新分派。

## 推荐提示词

### 先探索

```text
Spawn feature_mapper and getx_reviewer in parallel.
Have feature_mapper map the real code path for <task>.
Have getx_reviewer inspect GetX lifecycle and shared-state risks for the same path.
Wait for both and summarize:
1. owning files
2. shared hotspots
3. whether parallel write work is safe
```

### 市场/库存/售卖实现

```text
Use feature_mapper first to map the affected code path for <task>.
Then have market_shop_worker implement the smallest defensible fix.
If shared files outside its scope are required, stop and report them instead of editing them.
Finally have test_guard run the relevant validation and summarize remaining risks.
```

### 账户/钱包/登录实现

```text
Spawn feature_mapper for code-path mapping.
Then use account_wallet_worker to implement <task> in the smallest safe way.
Do not let it modify app bootstrap, routes, bindings, or navbar integration unless explicitly reassigned.
After implementation, run test_guard and summarize findings.
```

### PR 风险审查

```text
Review this branch with parallel subagents.
Use feature_mapper to map affected code paths.
Use getx_reviewer to find lifecycle, dependency-injection, and shared-state risks.
Use test_guard to identify missing or weak validation.
Wait for all of them and summarize findings with file references.
```

## 这个仓库的现实建议

这个项目最适合的 subagent 模式不是“很多写代码 agent 同时下手”，而是：

- 读型 agent 并行
- 写型 agent 串行
- 主线程负责共享边界和最终集成

原因很直接：

- `GetX` 全局依赖较多
- `custom_navbar`、`UserController`、`CurrencyController`、`filter` 是高冲突区
- 现有测试覆盖较薄
- 几个页面文件非常大，不适合多人同时写

因此，官方意义上更稳妥的设计是：

- 把 subagents 做成窄职责专家
- 把协调留在主线程
- 把共享规则写进 `AGENTS.md`
- 把真正可 spawn 的 agent 写进 `.codex/agents/*.toml`

这套结构已经在仓库里落好了。
