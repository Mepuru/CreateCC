# CHANGELOG — stock_controller

## v0.2.0 (2026-09-20, 未在游戏内验证)

按用户实际配置定制：

- **物品**：虫蚀石砖 `minecraft:infested_stone_bricks`
  （id 来源：本地 `client-1.21.1-20240808.144430-extra.jar` → `assets/minecraft/lang/en_us.json`
  的 `block.minecraft.infested_stone_bricks`，非猜测）
- **地址**：`经验`（frogport 物流地址）
- **显示屏**：CC 显示器（`display.kind = "monitor"`，带颜色）
- **下单**：红石请求器（`setRequest` + `request()`），`craft = false`
- **红石**：电脑自带红石面，默认 `left` / 不足输出 15

代码改动：

- 请求器单槽 256 上限处理：`batch > 256` 时**自动铺到多个槽**（最多 9 槽 = 2304），
  仍有剩余才告警（旧版是直接截断到 256）
- 显示屏**自适应排版**：宽度 <30 时切换紧凑格式（适配小尺寸 monitor）
- 启动时打印显示器实际尺寸，便于确认摆放/尺寸
- 显示屏优先级与回退保持：`monitor` → `Create_DisplayLink` → `term`

## v0.1.0 (2026-09-20, 未在游戏内验证)

首个版本：用 CC 电脑替代工厂仪表，带显示屏。

- 读库存：`Create_StockTicker.stock()`（仓库网络汇总，1 tick 缓存）
- 决策：`config.rules` 每物品 `low/high/batch/cooldown` + 滞回
- 下单：
  - `Create_RedstoneRequester`：`setRequest`（普通，单槽 ≤256，超出自动截断并告警）、
    `setCraftingRequest`（自动合成，`batches` 批数）、`setAddress`、`setConfiguration`
  - 无请求器时退回 `ticker.requestFiltered(address, {name=, _requestCount=})`
- 在途记账：状态落盘 `stateFile`（默认 `/stock_controller/state.tbl`），
  可用蛙港/邮筒 `package_sent`/`package_received` 事件按包裹内容核销
- 红石：电脑自带 `redstone` API 或 `redstone_relay`（规则里指定 `signal.peripheral`）
- 显示：`Create_DisplayLink` → `monitor` → `term` 自动选择；monitor/term 上带颜色状态
- 退出：`signalOnExit` 默认 `hold`，可设 `clear` 归零

### 复核过的 API（出处见 README）

- `StockTickerPeripheral`：`stock(detailed?)` 返回 1 基表 `{name, displayName, count}`；
  `requestFiltered(address, filters...)` 从第 2 个参数起是 filter 表，支持 `_requestCount`
- `RedstoneRequesterPeripheral`：`setRequest` 最多 9 槽、`count ≤ 256`；`setCraftingRequest(批数, 物品...)`；
  `setConfiguration` 仅接受 `"strict"` / `"allow_partial"`
- `DisplayLinkPeripheral`：`clear` / `setCursorPos` / `write` / `getSize` / `update`（**无** `setTextColour`，故纯文本）
- 事件参数：Create 原生外设事件第 1 个参数是外设挂载名（`SyncedPeripheral.queueEvent`），
  故 `package_*` 事件取第 2 个参数为 Package 对象

### 待实测/待确认

1. `stock()` 在大型网络（数百种物品）下的返回耗时 → 决定 `pollInterval` 是否要调大
2. package 事件核销的实际时序（包送到才触发？出发就触发？）→ 影响在途账本准确度
3. `setCraftingRequest` 的 `batches` 与实际产出数量的对应关系 → 影响记账（目前按 `batch` 估算）
4. DisplayLink 对中文/`label` 的显示宽度（当前默认 ASCII）
