# CHANGELOG — stock_controller

## v0.4.1 (2026-09-20, 未在游戏内验证)

用户实测反馈：屏幕显示 `NETWORK: ...ck_controller/main.lua:153:` —— 那是**缺库存查询器**时
`error()` 抛出的 Lua 错误原文（CC:T 会给消息加上 `路径:行号:` 前缀），在窄屏上被截成那样。

- 屏幕状态行改为 `shortError()` 处理（去掉 `路径:行号:` 前缀），文案缩短：
  - 缺查询器 → `NET: NO TICKER`（详细原因与解决办法打到电脑终端）
  - `stock()` 返回空 → `NET: NO DATA (freq?)`
- **读不到数据时库存显示 `?`（灰色）而不是 `0`**：避免把"未知"误看成"库存真空了"
- 其余失败（下单/红石）仍记录完整文本，屏幕上只显示可读部分

## v0.4.0 (2026-09-20, 未在游戏内验证)

- **修复中文乱码**：CC:T 的终端/显示器只有位图字体（jar 内 `assets/computercraft/textures/gui/term_font.png`，
  无 Unicode 字形提供器），**画不出汉字**。程序里所有会显示出来的文本（日志、状态、错误、标题）
  改为 ASCII 英文；中文只保留在注释、文档与**数据字符串**（`address = "经验"`）里。
- `config.display.title`：`经验库存` → `STOCK CONTROL`（注释写明原因）；`rule.label` 注释同步纠正
- 模板也一并处理：`code/templates/program.lua`、`code/templates/probe_peripherals.lua` 的
  `print`/`log` 文本全部 ASCII（探测输出现在是英文，仍可直接贴回给 Agent）
- 文档：`docs/ENVIRONMENT.md` 新增「2.4 显示能力：只能显示 ASCII（实测乱码）」，
  `AGENTS.md` 4.5/7.12 加入硬性规范与坑位
- 摆放信息：用户显示器在电脑**右侧**，`peripheral.find("monitor")` 自动定位；
  红石保持输出到空闲的 `left` 面
- 生成物的编码修复：Windows PowerShell 5.1 的 `>` 重定向会把输出写成 **UTF-16LE**
  （仓库里旧的 `docs/_generated_peripherals.txt` 就是这样，GitHub 上显示为乱码）。
  三个脚本新增 `--out <PATH>`（直接写 UTF-8/LF），文档里的命令全部改用它；
  两份实例快照不再入库，`_generated_peripherals.txt` 已重新生成
- 待用户实测：中文地址 `经验` 的字节往返（README 里有 10 秒自测脚本）；
  若 CC:T → Java 的字符串转换有损，回退方案是把 frogport 地址改成 ASCII

## v0.3.0 (2026-09-20, 未在游戏内验证)

- **阈值改为"常备 10K"**：`low = 8192` / `high = 10240` / `batch = 1024`
  （低于 8K 触发补货，补到 10K 视为达标并清空在途账本；每次下单 4 槽 × 256，冷却 30 秒）
- 语义确认：`decide()` 用 `在库 + 在途` 判断，所以在途未到货时不会重复下单；
  只有达到 `high` 才重置在途账本

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
