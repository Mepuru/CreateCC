# AGENTS.md — Create × CC: Tweaked Lua 工程规范

本文件是**后续所有 Agent 在本仓库工作时的最高优先级规范**。冲突时以本文件为准（除游戏内实测事实外）。

- 工程根目录：本仓库根目录（下文的 `docs/`、`code/`、`scripts/` 都相对它）
- 目标产物：可拷贝进**游戏内电脑**运行的 `.lua` 程序（Minecraft **1.21.1** + **NeoForge** + Create **6.0.x** + CC: Tweaked）
- 资料目录：`docs/`（一手资料快照，见 `docs/INDEX.md`）
- 代码目录：`code/`（所有交付代码写在这里）
- 本仓库**不包含** Minecraft、mod jar、游戏存档；只放资料与代码。

---

## 0. 第一件事：读实测环境

**不要**从版本矩阵猜现场。先读 **`docs/ENVIRONMENT.md`**（用户当前实例的真实快照：整合包、版本、
已装/未装的 CC 相关 mod、实际可用的外设与 Lua API）。它变了就跑：

```bat
python scripts\scan_mods.py --mods "<实例>\mods" --out docs\_mods_scan.txt
python scripts\dump_jar_peripherals.py --mods "<实例>\mods" --extract-rom docs\rom_extras --out docs\_instance_peripherals.txt
```

再让用户在游戏里跑 `code/templates/probe_peripherals.lua`，把输出贴回来——
**"世界里放了什么"只有这个能看出来**。

当前实例速览（详见 `docs/ENVIRONMENT.md`）：Mechanomania 1.1.12.0 ｜ MC 1.21.1 ｜ NeoForge 21.1.248 ｜
Create 6.0.10 ｜ CC:T 1.120.2 ｜ **未装 CC:C Bridge** ｜ 另有 6 个 mod 提供 CC 集成面。

---

## 1. 环境与版本矩阵（写代码前必须先确认）

| 组件 | 实测值 | 说明 |
|---|---|---|
| Minecraft | **1.21.1** | |
| 加载器 | **NeoForge 21.1.248** | 1.21.1 的 Create 官方只有 NeoForge；Create Fabric 停在 1.20.1 |
| Create | **6.0.10** | 提供 18 个原生 CC 外设（`Create_*`） |
| CC: Tweaked | **1.120.2** | 文件名带 `-forge-`，实际是 NeoForge 构建 |
| CC:C Bridge | **未安装** | `docs/API_CCCBridge.md` 仅作将来加装的参考；现在写依赖它的代码会失败 |
| 其它 CC 集成提供方 | **6 个**：Create: Additional Logistics、Bits 'n' Bobs、Diesel Generators、Electro Energetics、CC: Sable、Create Ore Excavation | 清单见 `docs/API_INSTANCE_ADDONS.md` |
| 可选（未装） | `CCCCC`、`CC:LiftLink`、`cbcperipheral`/`CC:CBC`、`CC: Create Compat+` | **只在用户确认装了**时才允许依赖 |

> 用户报的版本与本表/`ENVIRONMENT.md` 不一致 → **停下来问**，不要"猜着兼容"。不同版本 API 会变。
> 本文件里的版本是 2026-09-20 的快照；`docs/ENVIRONMENT.md` 更新后以它为准。

---

## 2. 资料使用规范（唯一可信来源）

1. **API 必须有出处**。写每个外设方法/事件前，先在 `docs/` 里找到它，并在代码注释里标注来源路径。
2. 权威顺序：**源码 / jar 实测**（`docs/create-source`、`docs/cc-tweaked`、`docs/cccbridge`、`_instance_peripherals.txt`）
   > **官方 wiki / mod 自带文档** > 其他一切。
3. 类型名字符串**区分大小写**：
   - Create 原生：`Create_Station`、`Create_Frogport`、`Create_DisplayLink` …（`docs/API_CREATE_NATIVE.md`）
   - 本实例 addon：`CreateAdditionalLogistics_*`、`Create_Bits_N_Bobs_Headlamp`、`CDG_ChemicalTurret`、
     `ElectroEnergetics_ElectricGauge`（`docs/API_INSTANCE_ADDONS.md`）
   - CC:C Bridge（**本实例未装**）：`create_source`、`create_target`、`redrouter`、`scroller`、`animatronic`
4. **禁止臆造 API**。不确定就查；查不到就要求用户跑探测脚本，不要写"大概是这样"。
5. **禁止照抄文档里的示例代码**：已发现文档示例有笔误（`peripheral.fid`、`setLocked`、事件名 `speed` vs `speed_change`）。
   示例可参考，函数签名以函数表/源码为准。
6. 涉及 CC:T 自身 API（`peripheral`/`fs`/`term`/`rednet`/`os`/`textutils`…）时，查 `docs/cc-tweaked/` 或在线 https://tweaked.cc 。
7. 语言特性不确定时查 `docs/cc-tweaked/doc/reference/feature_compat.md`（CC:T = Cobalt，Lua **5.2** 语义 + 部分 5.3/5.0 特性）。
   **不要**用 PC 端 Lua 5.1/5.4 的经验直接下结论。
8. **CC:T 的集成面有三种，别只找外设方块**（本实例三种都有）：
   1. **外设方块** —— `peripheral.find("X")`，见 `docs/API_CREATE_NATIVE.md` + `docs/API_INSTANCE_ADDONS.md`；
   2. **Lua ROM 附加** —— 新增的**全局 API**与 **`require` 模块**（本实例由 CC: Sable 提供
      `aero` / `matrix` / `quaternion` / `sublevel` 与 `advanced_math.*`，**不需要贴任何方块**）；
      真实文件已抽取到 `docs/rom_extras/cc_sable/`；
   3. **turtle 升级** —— 例：`createoreexcavation:vein_finder`。
   这三种都可能带自己的事件与方法，且**只在装了对应 mod 的机器上存在**。
9. **读数优先用这四层**（都**不需要**额外 mod，详见 `docs/API_CREATE_NATIVE.md` 末尾"读取速查"）：
   Create 专用外设（转速表/应力表/列车站/库存查询器/蛙港…）→ CC:T **通用外设**
   `inventory` / `fluid_storage` / `energy_storage`（读任意暴露物品/流体/能量能力的方块，含 Create 储罐与容器）
   → CC:T `redstone_relay`（读红石模拟量 0–15）→ 外设事件。**能读到什么必须实测**，别只看文档。
10. `docs/_mods_scan.txt` 与 `docs/_instance_peripherals.txt` 是**本地生成**的环境快照
    （`scripts/scan_mods.py` / `scripts/dump_jar_peripherals.py`），**不进版本库**——
    新克隆的仓库里没有这两个文件，需要时自己对着自己的实例跑一遍。

---

## 3. 开工前：必须向用户索取的信息（交接清单）

> 用户给的任务描述通常不够。**缺哪一项就停下来问**，一次问清楚，不要靠猜然后返工。
> 模板：`code/templates/TASK_REQUEST.md`（让用户填这个，或按下面清单逐条问）。

### A. 环境（决定能不能用某个 API）
0. **先自己跑**：`scripts/scan_mods.py` + `scripts/dump_jar_peripherals.py`，对齐 `docs/ENVIRONMENT.md`；
   计划里用到的每个 API，都要确认它来自"已装的 mod"而不是"文档里存在"。
1. Minecraft / Create / CC: Tweaked / CC:C Bridge 的**精确版本号**（与快照不符时以用户为准并更新快照）。
2. 还装了哪些相关 mod（CCCCC？火炮？Power Grid？Aeronautics？）——决定可用外设集合。
3. 单人还是服务器；服务器**是否允许** CC:T 的 `http` API（`wget`/`pastebin` 下载）、是否能装/改 mod。
   ⚠️ 客户端 mods 不等于服务端有；外设与 ROM API 由服务端提供。

### B. 现场硬件（决定脚本怎么写"发现外设"）
4. 电脑种类与数量（普通 / 高级 / 命令电脑；turtle 还是 computer），是否有显示器、扬声器。
5. 每台电脑旁边/网络中**实际有哪些外设**、在哪个面（`left`/`right`/`top`…）或通过哪个 modem。
   → 让用户运行 `code/templates/probe_peripherals.lua` 并把输出贴回来（这是最关键的一条）。等价的最小命令：
   ```lua
   for _, n in ipairs(peripheral.getNames()) do print(n, peripheral.getType(n)) end
   ```
6. 是否需要贴中文/特殊符号（先看 `docs/cccbridge/docs/guides/charset.md`，并在游戏里试打一次）。

### C. 通信拓扑
7. 有线 modem 还是无线（Ender）modem？频道号？是否需要 GPS（`docs/cc-tweaked/doc/guides/gps_setup.md`）。
8. 多台电脑是否需要协作（谁发谁收、谁是主控），跨区块是否常驻加载（chunk load）。

### D. 功能需求（决定程序结构）
9. 一句话目标 + 触发方式（事件驱动 / 周期轮询 / 玩家点击屏幕）。
10. 输入与输出具体是什么（读哪个数值、写到哪块屏/哪个红石面）。
11. 异常时该怎么表现（重试？报警？停机？打印日志？）。
12. 精度/频率要求（每 tick？每秒？每分钟？）——直接影响 CPU 占用与是否需要 `os.startTimer`。
13. 是否需要持久化状态（重启后恢复）、是否需要 `startup.lua` 开机自启。

### E. 交付与验收
14. 代码在电脑里的**目标路径**（如 `/create_cc/train.lua`），是否要多个文件/库。
15. 注释与文档语言（中文/英文）。
16. **验收场景**：用户会在游戏里怎么测、期望看到什么输出（Agent 要给出可执行的验证步骤）。
17. 失败时用户能提供什么：**报错全文**、第 5 条的探测输出、`os.version()`。

---

## 4. 硬性编码规范

### 4.1 结构与发现外设
- **先探测、后绑定**。启动时用 `peripheral.getNames()` / `peripheral.find(type)` 查找，找不到就**明确报错并说明该把方块放哪**。
- 不要硬编码 `"left"` / `"right"`，除非用户明确指定了安装位置。
- `peripheral.find` 返回 `(name, wrapped)` 两个值，别只接一个还以为是外设对象：
  ```lua
  local name, station = peripheral.find("Create_Station")
  ```
- 一个电脑可能有多个同类外设（多块屏/多个蛙港）→ 支持按名字选择，或在文档里说明取第一个。
- 依赖 addon / ROM API 的程序要**降级可用**：`if not aero then ... end`、`pcall(require, "advanced_math.stats")`，
  缺了就打印清楚的提示，而不是直接崩。

### 4.2 调用与容错
- 所有外设调用视为**可能抛错**（外设被拆、被卸载、参数非法）。关键路径用 `pcall`，失败时打印 `外设名 + 方法名 + 错误`。
- 程序要有"外设消失"的处理：监听 `peripheral` / `peripheral_detach` 事件，或在每次调用失败后重新 `peripheral.find`。
- 长时间运行的程序必须能响应 `terminate`（Ctrl+T）：在事件循环里 `if event == "terminate" then break end`，并在退出前把外设恢复到安全状态（解锁、停输出、关红石）。

### 4.3 事件循环
- 用 `os.pullEvent()` / `os.pullEventRaw()`；需要定时就用 `os.startTimer(seconds)`，**不要 `while true do end` 忙等**，也不要 `sleep(0)` 死循环。
- 事件名与参数**逐字对照** `docs/API_*` + 源码。特别注意：Create 原生外设的事件**第一个参数是外设挂载名（attachment name，如 `left`/`right`）**，
  源码依据（`SyncedPeripheral.java` 第 65–78 行 javadoc：“Adds the peripheral attachment name as 1st event argument”）：
  ```lua
  local event, side, stationName, trainName = os.pullEvent("train_arrival")
  ```
- **addon 外设的事件/方法名同样只能靠探测**：`_instance_peripherals.txt` 里已有候选，但事件参数顺序必须用
  `probe_peripherals.lua` 或实测脚本确认，不要照搬 Create 原生外设的习惯。
- 用 `os.pullEvent(name)` 过滤时注意：过滤掉的事件会被丢弃，若还要处理 `terminate` 等，用并行 `parallel.waitForAny` 或多个 filter 分支。

### 4.4 模块化与文件
- 可复用逻辑放 `code/lib/*.lua`，文件**末尾 `return` 一个 table**（`docs/cc-tweaked/doc/guides/using_require.md`）。
- `require("name")` 走 `package.path`，**不是**文件路径；子目录用 `require("a.b")`，对应 `a/b.lua`。
  → 交付时必须说明**每个文件在电脑里的落盘路径**（相对路径保持一致，否则 `require` 会找不到）。
- 注意区分"ROM 自带模块"（如 `advanced_math.stats`，任何电脑都能 `require`）与"你自己的库文件"（要拷进电脑）。
- 文件名：小写 + 下划线，`.lua` 结尾，**不要中文文件名**。
- 每个文件顶部必须写头部注释块（见 `code/templates/program.lua`）：
  依赖 mod 与版本、需要的外设及类型名、监听的事件、用法示例、**API 出处**。

### 4.5 其他
- 不要用游戏中不存在的能力：无网络请求（除非用户确认开了 http）、无第三方 Lua 库、无操作系统命令。
- 不要占用大量 CPU/内存：循环里不要做重字符串拼接，长列表用 `table.concat`，日志要限流。
- 屏幕类程序注意 `term`/`window` 的 API 差异（CC:C Bridge 的 `create_source` 是"类 Terminal"，不支持格式化文本，
  且**同步频率 1 秒**——但那需要先装 CC:C Bridge，本实例没有）。
- **显示文本一律 ASCII**：CC:T 只带一张位图字体（jar 内 `assets/computercraft/textures/gui/term_font.png`，
  无 Unicode 字形提供器），**终端/显示器画不出汉字，实测乱码**。
  中文只能出现在：① 注释与文档 ② **数据字符串**（如物流地址 `address = "经验"`，只参与比较、不绘制）。
  `print`/`log`/屏幕绘制、`config` 里的 `title`/`label` 全部用英文。

---

## 5. 代码区约定（`code/`）

```
code/
├── README.md              目录与命名约定、如何把代码送进游戏
├── lib/                   可复用库（跨项目共享；改动需在 CHANGELOG 注明影响范围）
├── create-native/         只依赖 Create 原生外设的项目
├── cccbridge/             依赖 CC:C Bridge 外设的项目（本实例未装，先确认用户是否加装）
├── templates/             program.lua / lib.lua / probe_peripherals.lua / TASK_REQUEST.md（不要直接改模板）
└── <project_name>/        每个用户任务一个目录（小写+下划线）
    ├── main.lua           入口
    ├── lib/*.lua          该项目私有库（可选）
    ├── README.md          部署路径、外设要求、运行方法、已验证环境
    └── CHANGELOG.md       变更记录（含"因版本升级复核了哪些 API"）
```

命名建议：`train_dispatch.lua`、`stock_monitor.lua`、`animatronic_greeter.lua`。

> 用到 addon 外设/ROM API 的项目，建议单独放目录（如 `code/<project>/`）并在 README 里写清"需要哪些 mod"。

---

## 6. 标准工作流程

0. **探环境**：读 `docs/ENVIRONMENT.md`；需要时跑 `scripts/scan_mods.py` + `scripts/dump_jar_peripherals.py`；
   让用户跑 `probe_peripherals.lua` 并贴回输出。
1. **接单**：读用户任务。按第 3 节清单核对信息；缺失项列成问题一次性问清（不要边猜边写）。
2. **复述**：用 3–6 行复述"要做什么、跑在哪、用什么外设、验收标准"，请用户确认（尤其是外设类型名与落盘路径）。
3. **定 API**：在 `docs/` 里逐个确认用到的类型名/方法/事件，把出处记下来（写进代码注释）。
4. **写代码**：先做**最小可运行版本**（能探测外设 + 打印/最小动作），再加功能；不要一次写完 500 行没验证过的代码。
5. **静态自检**（交付前逐条过）：
   - [ ] 每个类型名字符串都能在 `docs/API_*.md`、`_instance_peripherals.txt` 或源码里找到（大小写一致）
   - [ ] 每个方法名、事件名都能在 `docs/` 找到出处
   - [ ] 事件参数顺序与源码 `queueEvent(...)` / probe 输出一致（Create 原生第一个参数是外设名）
   - [ ] 每个外设调用都在 `pcall` 内或有明确失败处理；addon/ROM API 有缺省降级
   - [ ] 有 `terminate` 退出路径，退出时恢复现场
   - [ ] `end` / `then` 配平，没有全局变量泄漏（用 `local`）
   - [ ] 若本机装了 Lua：`luac -p <file>.lua` 通过（没有就如实说明"未做机器语法检查"）
6. **交付**：在项目 `README.md` 写清落盘路径、外设清单、启动方式、**依赖的 mod 与版本**；
   给出**游戏内验证步骤**（3–6 步 + 期望输出 + 失败时要回报什么）。
7. **回归**：用户回报结果后修正；通过则更新 `CHANGELOG.md`。

> 注意：本仓库没有 Minecraft 环境，**Agent 无法自行运行验证**。所以"未验证"必须如实说明，
> 并把验证步骤交给用户执行——这是流程的一部分，不是可选项。

---

## 7. 常见坑（写之前扫一眼）

1. **装置（contraption）上的电脑**：动力轴承/矿车/电梯等移动结构上的 CC 电脑**原生不能正常工作**，
   需要 CCCCC 等 mod（本实例没装）；Sable 的物理子层级是另一套（`sublevel` API）。遇到"跟着装置走"的需求先确认装了什么。
2. **外设连接**：外设必须与电脑相邻，或通过有线/无线 modem 组网。`peripheral.find` 只能找到**已连接**的外设。
3. **事件参数前缀**：Create 原生外设事件第一个参数是外设名（见 4.3）。
4. **文档笔误**：`speedometer` 事件是 `speed_change`；CC:C Bridge 示例里的 `peripheral.fid`、`setLocked` 是错的。
5. **Scroller Pane 只能从背面 attach**（CC:C Bridge，本实例未装）；`create_source` 同步频率 1 秒。
6. **终端字符集**：写中文/符号前先看 `docs/cccbridge/docs/guides/charset.md` 并在游戏内实测。
7. **同名外设多个**：`peripheral.find` 只返回第一个匹配项；多屏/多蛙港场景要按 `peripheral.getNames()` 遍历选择。
8. **`startup.lua`**：开机自启文件名与位置规则见 `docs/cc-tweaked/doc/reference/startup.md`；自启程序崩溃会挡住 shell，务必自己兜 pcall。
9. **别把"文档里有"当成"现场能用"**：CC:C Bridge 整套 API 在本实例都不存在；
   addon 外设（Additional Logistics / Diesel Generators / Electro Energetics / Bits 'n' Bobs / CC: Sable）
   只在这套装了才有。程序要跨环境跑，就必须做能力探测。
10. **ROM 附加与 CC:T 版本绑定**：CC: Sable 通过 `data/computercraft/lua/rom/...` 注入 `aero`/`matrix`/`quaternion`/`sublevel`
    与 `advanced_math.*`。升级 CC:T 或换包后要重跑 `dump_jar_peripherals.py --extract-rom`。
11. **turtle 升级**是独立的集成面（本实例有 `createoreexcavation:vein_finder`）：
    程序里要用 `turtle.equipLeft/Right` 之类配合，且只有 turtle 电脑才有。
12. **中文会乱码**：CC:T 无 CJK 字形（见 4.5），任何"给玩家看"的文本都用 ASCII；
    写中文日志/标题 = 屏幕上一堆方块或问号（踩过一次：`display.title = "经验库存"`）。

---

## 8. 版本升级 / 资料更新流程

用户换版本（例如 Create 6.0.11、CC:T 1.121）或换整合包时：

1. **重扫实例**（最重要）：
   ```bat
   python scripts\scan_mods.py --mods "<实例>\mods" --out docs\_mods_scan.txt
   python scripts\dump_jar_peripherals.py --mods "<实例>\mods" --extract-rom docs\rom_extras --out docs\_instance_peripherals.txt
   ```
   然后把要点写进 `docs/ENVIRONMENT.md`（版本、已装/未装、外设与 ROM API 变化）。
2. `python scripts/refresh_docs.py` 更新上游资料快照；
3. `python scripts/dump_create_peripherals.py --out docs/_generated_peripherals.txt`，与 `docs/API_CREATE_NATIVE.md` 比对；
4. 更新 `docs/INDEX.md` 的 branch/commit/日期；
5. 在项目 `CHANGELOG.md` 记录"因版本升级复核了哪些 API、有无变化"。

---

## 9. 快速参考

- **实测环境**：`docs/ENVIRONMENT.md`（先读这个）
- 本实例额外 API：`docs/API_INSTANCE_ADDONS.md`、`docs/rom_extras/cc_sable/`、`docs/_instance_peripherals.txt`
- Create 原生外设表：`docs/API_CREATE_NATIVE.md`
- CC:C Bridge 外设表（本实例未装）：`docs/API_CCCBridge.md`
- 资料路由表 / 版本矩阵：`docs/INDEX.md`
- 代码模板：`code/templates/program.lua`、`code/templates/lib.lua`、`code/templates/probe_peripherals.lua`
- 任务单模板（给用户填）：`code/templates/TASK_REQUEST.md`
