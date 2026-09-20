# stock_controller — 用 CC 电脑替代工厂仪表（带显示屏）

一台电脑同时盯 **N 种物品**：读仓库网络库存 → 按规则判断 → 不足就下单补货 → 输出红石 → 刷新显示屏。
相当于"多面板工厂仪表 + 补货打包机 + 自定义策略"，且全部使用 **Create 原生外设 / CC:T 自带能力**，不需要额外 mod。

## 文件与部署路径

| 本仓库文件 | 游戏电脑里的路径 |
|---|---|
| `main.lua` | `/stock_controller/main.lua` |
| `config.lua` | `/stock_controller/config.lua` |

两个文件必须在**同一个目录**（`require("config")` 按当前程序目录解析）。
运行：在电脑 shell 里输入 `stock_controller/main`，或 `cd stock_controller` 后运行 `main`。
自启：把 `shell.run("stock_controller/main")` 写进 `/startup.lua`（规则见 `docs/cc-tweaked/doc/reference/startup.md`）。

## 本实例的实际配置（2026-09-20 已确认）

| 项 | 值 |
|---|---|
| 监控物品 | **虫蚀石砖** = `minecraft:infested_stone_bricks`（已从你本地 `client-1.21.1-...-extra.jar` 的 `en_us.json` 核对：`block.minecraft.infested_stone_bricks`） |
| 目标地址 | **`经验`**（frogport 的物流地址；必须与游戏里完全一致，含中文） |
| 显示屏 | **CC 显示器**（`config.display.kind = "monitor"`，带颜色；宽 <30 自动换紧凑排版） |
| 下单方式 | **红石请求器已装** → 走 `Create_RedstoneRequester`（`setRequest` + `request()`） |
| 自动合成 | **关闭**（`craft = false`）：虫蚀石砖原版不是合成品；如果你的整合包用 KubeJS 加了配方，可改成 `craft = true` |
| 红石输出 | 用**电脑自带**的红石面，默认 `left`（显示器在右侧，`left` 空闲），不足时输出 15；要换面改 `signal.side`，要多路/远距离就在规则里写 `signal.peripheral = "redstone_relay_0"` |
| 阈值 | **常备 10K**：`low = 8192`（低于就补）／`high = 10240`（补到 10K 算够）／`batch = 1024`（每次 4 槽 × 256，30 秒冷却） |

## 需要的外设

| 用途 | 状态 | 类型名 | 说明 |
|---|---|---|---|
| 读仓库库存 | **必需** | `Create_StockTicker` | 必须**加入仓库的物流网络**：用**打包机链接（Stock Link）物品**右键仓库的 Stock Link 调谐，再右键查询器（或用调谐好的物品放置查询器）。**不是**用"频率"物品——那是红石链接系统的 |
| 下单 | **已确认有** | `Create_RedstoneRequester` | 同样要在这条物流网络上（它的物品就是可调谐物品）；地址由程序用 `setAddress("经验")` 写入 |
| 显示屏 | **已确认有** | `monitor`（CC 显示器） | 程序会打印实际尺寸；`Create_DisplayLink`、电脑屏幕作为回退 |
| 附加红石 | 可选 | `redstone_relay` | 现在没用；将来多路输出时规则里写 `signal.peripheral`（挂载名） |
| 在途核销 | 可选 | `Create_Frogport` / `Create_Postbox` | 电脑接在蛙港/邮筒上时按包裹内容核销在途；不接则只在达到 `high` 时清零 |

外设可以贴着电脑，也可以走有线/无线 modem 网络。

## 配置要点（`config.lua`）

- `rules[]`：每项 `{ item, label, low, high, batch, address, craft, batches, cooldown, signal }`
  - `low` 低于它下单；`high` 达到它清空在途账本（滞回，避免抖动）
  - `address` 目标蛙港地址；`craft = true` 走自动合成（`batches` 为批数）
  - `signal = { side = "left", lowLevel = 15 }`：库存不足时把该面输出拉到 15；`peripheral = "redstone_relay_0"` 可改用继电器
- `pollInterval`：默认 2 秒。`stock()` 每次返回整张网络且跑服务端主线程，**别设太小**
- `cooldown`：同一物品两次下单的最小间隔（默认 30 秒）
- `orderVia`：`auto` / `ticker` / `requester`
- `reconcilePackages`：是否用 package 事件核销在途
- `signalOnExit`：`hold`（默认，停机保持红石现状）/ `clear`（归零）
- `display.title / color / widthLimit`：显示屏标题、monitor 上是否用颜色、行宽上限

## 显示内容

```
STOCK CONTROL
upd 0s ago  inflight 1024
------------------------
Infested Bricks    7600/8192  LOW +1024
last: Infested Bricks +1024
```

- `OK` 绿（达到 `high`）/ `..` 黄（在 low~high 之间）/ `LOW` 红（含在途仍不足）
- `+N` = 在途数量；`inflight` = 全部规则的在途合计
- **读不到网络数据时**：状态栏显示 `NET: <原因>`，库存列显示灰色 `?` —— `?` 是"未知"，不是 0。
  常见原因是缺库存查询器（`NET: NO TICKER`）或它没接进仓库的物流网络（`NET: EMPTY NETWORK (freq?)`），
  详细原因和解决办法会打印在**电脑终端**上。
- 只有 monitor/term 支持颜色；`Create_DisplayLink` 会忽略颜色（纯文本），这是它的固有限制

> ⚠️ **显示文本必须是 ASCII**。CC:T 只带一张位图字体（jar 内 `assets/computercraft/textures/gui/term_font.png`，
> 没有任何 Unicode/字形提供器），**终端和显示器画不出汉字，实测乱码**。
> 中文只能出现在：① 代码注释与文档 ② **数据字符串**（如物流地址 `address = "经验"`）。
> 任何会 `print`/写到屏幕的内容都用英文。

## 游戏内验证步骤（按你的配置定制）

1. **接进物流网络**：拿**打包机链接（Stock Link）物品**右键仓库里正在工作的 Stock Link（物品变成金色"已连接"），
   再拿它右键**库存查询器**（详见 `INSTALL.md` §3.6）。**不要**用「频率」物品——那是红石链接系统。
   这一步错了的表现是：屏幕一直显示 `NETWORK: ...` 或所有物品数量为 0。
2. **摆电脑与显示器**：显示器在电脑**右侧**（`peripheral.find("monitor")` 会自动找到，不用写侧面）；
   库存查询器/红石请求器贴着电脑或经 modem 接入。启动后看终端输出：
   `stock controller up: ...`、`display size WxH`、`ticker: ... | requester: connected`。
3. **先只看不控**：把 `config.lua` 里 `low = 0`（永不触发下单）、`signal` 那行删掉或注释，
   运行 `stock_controller/main`，确认屏幕上的数量**与库存查询器 GUI 里的虫蚀石砖数量一致**。
4. **恢复阈值并观察下单**：把 `low` 改回 **8192**（想更快看到效果就先临时设成略高于当前库存的值，比如当前 9000 就设 `low = 9000`），
   等 2 秒（一轮轮询）后应看到：
   - 终端打印 `ordered minecraft:infested_stone_bricks x1024 (inflight total 1024)`
   - 显示器上该行变成 `LOW +1024`
   - 蛙港/打包机开始动，包裹发往地址 `经验`
5. **验红石**：在电脑 `left` 面接红石灯/比较器（右侧被显示器占用，左侧空闲），
   不足时应输出 15（灯亮），补到 `high` 后归 0。
6. **验重启**：Ctrl+T 退出再启动，看是否打印 `restored N inflight entries`、屏幕数值正常。
7. **（可选）验核销**：把电脑接到发往 `经验` 的蛙港上，收到包裹时应在途数按包裹内容下降。

> 阈值建议：`batch` 取 256 的整数倍最省事（单槽上限 256，程序会自动铺到最多 9 槽 = 2304）。
> `high - low` 最好 ≥ `batch`，否则补一次就超过上限、滞回失效。

## 已做的检查（以及没做的）

✅ 静态检查：块配平、无全局变量泄漏、无"注释吞代码"、无 `colors`/`redstone` 等 CC:T 全局被局部变量遮蔽；
所有 API 名逐个对照源码（`StockTickerPeripheral` / `RedstoneRequesterPeripheral` / `DisplayLinkPeripheral`）；
物品 id 从你本地客户端 jar 的语言文件核对。

❌ **本机没有 Minecraft，程序未在游戏内运行验证**——请按上面 7 步实测，有问题把**报错全文 + 屏幕内容**发我。

## 中文地址自测（`address = "经验"` 到底能不能用）

CC:T 的 Lua 字符串是字节串，传给 Create 时要转成 Java 字符串；**这个转换是否按 UTF-8 解释，
我无法在离线环境里证实**（Cobalt 运行时是 JarJar 嵌套 jar，编码路径不在证据链上）。
花 10 秒在游戏里验一下，**用字节比较而不是看屏幕**（屏幕画不出汉字）：

```lua
local r = peripheral.find("Create_RedstoneRequester")
r.setAddress("经验")
local back = r.getAddress()
print(#back, back == "经验")   -- 期望输出：6   true
```

- 输出 `6   true` → 往返无损，`config.lua` 保持 `address = "经验"`。
- 输出不是 `6   true`（例如 `6   false`，或字节数不是 6）→ 说明转换有损：
  把 **frogport 的地址**和 **`config.lua` 的 `address`** 一起改成 ASCII（例如 `xp`），其余不用动。

## 已知限制（替换仪表时要注意）

1. **在途数量靠记账**：仪表的 `getPromised()` 是内部 `RequestPromiseQueue`，CC 读不到；
   本程序只能"下单时 +N、收到 package 事件时按包裹内容 -N"。**不让电脑接蛙港/邮筒就不会核销**，
   只会在 `high` 达到时清零。第一次上线建议先跑几天和仪表对账。
2. **自动合成依赖网络里有配方/合成能力**；CC 无法查询配方，`batches` 需要你自己定。
3. **区块未加载的物流链接不计入汇总**：屏幕数字会偏小（仪表会显示"等待网络"，CC 看不到这个状态）。
   要么让仓库常驻加载，要么把 `low` 留出余量。
4. **`requestFiltered` / `request()` 是异步的**：包要几秒到；程序已用 `cooldown` + 在途账本防抖，
   但仍建议 `cooldown ≥ 30`。
5. **仪表之间的连线（生产计划 DAG）**没有对应物——需要多级依赖关系时直接在 Lua 里写（本程序只做单级补货）。
6. **本程序未在游戏内验证**：静态检查（块配平、无全局泄漏、API 名逐个对照源码）已做，
   但仓库里没有 Minecraft 环境，运行时行为需要你按上面第 3~6 步实测。
7. `label` 默认用 ASCII。要显示中文，先按 `docs/cccbridge/docs/guides/charset.md` 确认你的显示屏/字体支持，
   并在游戏里试打一次再改。

## API 出处（改代码前核对）

- `docs/create-source/.../compat/computercraft/implementation/peripherals/StockTickerPeripheral.java`（`stock`、`requestFiltered`）
- `docs/create-source/.../compat/computercraft/implementation/peripherals/RedstoneRequesterPeripheral.java`（`setRequest`、`setCraftingRequest`、`setConfiguration`、`request`）
- `docs/create-source/.../compat/computercraft/implementation/peripherals/DisplayLinkPeripheral.java`（`clear`、`setCursorPos`、`write`、`getSize`、`update`）
- `docs/create-source/.../content/logistics/packagerLink/LogisticsManager.java`（网络汇总与缓存语义）
- `docs/create-wiki/src/users/cc-tweaked-integration/`（官方 API 文档，逐外设一页）
- `docs/API_CREATE_NATIVE.md`（读取速查 + "用 CC 替代工厂仪表"章节）
