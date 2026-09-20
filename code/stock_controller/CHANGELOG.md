# CHANGELOG — stock_controller

## v0.7.1 (2026-09-20, 未在游戏内验证)

- 新增 **`update.lua`（一键更新器）**：`stock_controller/update [--keep]` 下载 main.lua/config.lua，
  **读回文件并打印其中的版本号**，最后提醒重启程序——专治"以为更新了其实没换"（本轮踩到）
- 按钮布局再修：改为**紧贴内容下方**（大屏上贴最底部离数据太远，用户 50x26 的屏上完全看不到）
- 头部显示短版本（`STOCK CONTROL  v0.7`），启动日志改为 `stock_controller v0.7.0 starting` + `display: ...`，
  便于一眼确认跑的是哪个构建
- INSTALL 新增「6. 更新文件」（一键更新器 + 手动更新 + 版本确认方法）

## v0.7.0 (2026-09-20, 未在游戏内验证)

用户要求：在显示器上加按钮，点一次发一次请求，或能设目标数量。

采用「四个按钮」方案（比两个更实用：调阈值不用回电脑改文件）：

| 按钮 | 作用 |
|---|---|
| `[ORDER]` | 手动下单一次（3 秒防连点，反馈显示在倒数第二行） |
| `[AUTO]` | 自动补货开关（绿=开/红=关；关闭时状态行显示 `AUTO OFF`） |
| `[LOW-]` / `[LOW+]` | 现场调目标阈值（±`config.buttonLowStep`，默认 1024；`high` 保持滞回宽度一起平移） |

实现要点：

- 触摸事件 `monitor_touch(外设名, x, y)`；只响应自己那块显示器，800ms 去抖
- 按钮行画在屏幕最后一行（反色背景），宽度不够时自动用 `[ORD]/[AUT]/[L-]/[L+]` 短标签
- **持久化**：`lowOverride` 与 `auto` 写进状态文件；启动时 `applyOverrides()` 套用到 rules，
  删除状态文件即可恢复 config.lua 的原始阈值
- 普通（非高级）显示器会打印提示：按钮需要高级显示器
- 新增 `config.buttonLowStep`

## v0.6.0 (2026-09-20, 未在游戏内验证)

用户实测反馈两件事：

1. **物品写错了**：实际要盯的是**虫蚀石头** `minecraft:infested_stone`，
   不是虫蚀石砖 `minecraft:infested_stone_bricks` → 配置已改（两个 id 都从客户端 jar 语言文件核对过）。
   这也是"网络里读到 0"的原因。
2. **请求器地址变成乱码**：程序执行 `setAddress("经验")` 后，请求器地址栏显示乱码、包裹送不到。
   → 确认 **CC:T 把 Lua 字符串按字节传给 Java，非 ASCII 会失真**（此前只是猜测，现在有实测证据）。

对策（v0.6.0）：

- `config.setAddressOnOrder`（默认 **false**）：程序**不再**写地址，请在红石请求器 GUI 里填目的地；
  想用 ASCII 地址（推荐，例如 `exp`）就设为 `true` 并同步改 frogport 地址
- 启动自检 `checkAddresses()`：
  · `address` 含非 ASCII 且会由程序写入时，打印 WARNING（告知必然乱码）
  · `setAddressOnOrder = false` 时打印"请求器当前地址 vs 配置期望地址"，不一致就提醒
- README 把"中文地址自测"一节改成「地址为什么不能是中文」（实测结论 + 三种处理方案 + 排查命令）

## v0.5.0 (2026-09-20, 未在游戏内验证) — **修掉"读不到查询器"的真正原因**

用户反馈"查询器就贴在电脑上、也做了绑定，程序还是说读不到"，并质疑思路。
复查 CC:T 1.120.2 的 **ROM 源码** `rom/apis/peripheral.lua`（第 332–345 行）：

```lua
function find(ty, filter)
    local results = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, ty) then
            local wrapped = peripheral.wrap(name)
            if filter == nil or filter(name, wrapped) then
                table.insert(results, wrapped)   -- 只装 wrapped
```

→ **`peripheral.find` 返回 0 个或多个"已包装外设表"，不返回 name**（老 CC1 的 `(name, wrapped)` 是过时语义）。

我的代码写的是 `local tickerName, wrappedTicker = peripheral.find("Create_StockTicker")`，
只有一个查询器时 `wrappedTicker` = **nil** → 程序判定"没有查询器"（`NET: NO TICKER`）。
**外设一直是好的，是程序自己在骗自己。**

修复：

- `rebind()`：`ticker = peripheral.find("Create_StockTicker")`；名字改用 `peripheral.getName()`（新增 `nameOf()` 帮助函数）
- `findDisplay()`：同样修掉——之前 `monitor` 那一支实际永远拿不到显示器，会静默退回电脑自带屏幕
- `requester` 同理修正
- `code/templates/program.lua` 的 `findAny()` 同步修正
- `AGENTS.md` §4.1 更正规范（附 ROM 出处），§7.7 换成这条最大的坑；§7.2 补"无线 modem 不能访问外设"
- `docs/API_CREATE_NATIVE.md` / `docs/API_INSTANCE_ADDONS.md` 里的示例代码同步修正

## v0.4.3 (2026-09-20, 未在游戏内验证)

**文档更正**：物流网络**不是**用「频率（Frequency）」物品绑的（我前几版写错了）。

- 依据：你 jar 内 `assets/create/lang/*.json` 的教程文本 "Right-click a Stock link before placement
  to connect to its network"；源码 `LogisticallyLinkedBlockItem.useOn()`（未调谐物品右键带网络的方块 →
  把该方块的网络 UUID 复制进物品）与 `StockTickerBlock.useItemOn()`（手持此类物品时把右键透传给物品处理）
- 正确做法（写入 INSTALL §3.6）：拿**打包机链接 Stock Link 物品**右键仓库的 Stock Link 调谐，
  再右键库存查询器；或直接用调谐好的物品放置查询器
- 「频率」物品属于**红石链接**系统，与物流网络无关
- 同步修正 README / config / main.lua 里的相关表述与提示文案

## v0.4.2 (2026-09-20, 未在游戏内验证)

安全护栏：**空网络不再当成"库存 0"**。

- 用户反馈"放了 Stock Ticker 也绑了频率还是读不到"。`stock()` 在频率不对/仓库区块未加载时
  会返回**空表**——旧版会把它当成"所有物品都是 0"，于是每 30 秒重复下单（很危险）。
- 现在空表按"读不到"处理：屏幕显示 `NET: EMPTY NETWORK (freq?)` + 库存列 `?`，不下单、不动红石；
  终端打印排查提示（频率要用 Frequency 物品从仓库 Stock Link 复制过来；仓库区块要加载）
- 新增配置 `config.emptyMeansUnknown`（默认 `true`；确实有"空仓库"场景可关掉）

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
