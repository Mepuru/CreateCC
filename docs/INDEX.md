# 资料地图（docs/）

本目录是 **Create × CC: Tweaked** 写 Lua 程序时的**唯一可信资料源**。
任何 API 名称、事件名、参数顺序，都必须能在这里找到出处；**禁止凭记忆或凭 PC 端 Lua 经验写代码**。

快照时间：2026-09-20 ｜ 实测环境见 **`ENVIRONMENT.md`**（优先级最高，写代码前先读它）。

---

## 1. 目录内容一览

| 路径 | 内容 | 上游 / 来源 | 分支 / commit | 权威性 |
|---|---|---|---|---|
| `ENVIRONMENT.md` | **用户当前实例的实测快照**：版本、已装/未装的 CC 相关 mod、实际可用的外设与 Lua API | 本地扫描生成 + 人工整理 | 2026-09-20 | **写代码前第一个读的文件** |
| `create-wiki/` | Create 官方 Wiki 源（Markdown） | https://github.com/Creators-of-Create/wiki | `main` / `bf1f31d` (2026-05-24) | 官方文档，**API 语义/事件的第一出处** |
| `create-source/` | Create **1.21.1** 的 CC 兼容源码（sparse） | https://github.com/Creators-of-Create/Create | `mc1.21.1/dev` / `fc9535d` (2026-09-16) | **源码级证据**：外设类型名、Lua 函数名、事件触发 |
| `cc-tweaked/` | CC: Tweaked 官方文档源 + 核心 API 源码（sparse） | https://github.com/cc-tweaked/CC-Tweaked | `mc-1.21.x` / `5c0c51d` (2026-09-15) | CC:T 自身 API / 语言特性 / 事件 |
| `cccbridge/` | CC:C Bridge 1.21.1 源码 + 自带 mkdocs 文档 | https://github.com/tweaked-programs/cccbridge | `mc1.21.1` / `73f2efa` (2026-06-11) | 该 mod 的外设与 API（**本实例未安装**） |
| `rom_extras/cc_sable/` | 从 jar 抽出的附加 Lua ROM 文件（`apis/` 全局 API、`modules/` 模块、`help/`） | CC: Sable 1.3.4 | 抽取自实例 | **真实签名** |
| `API_CREATE_NATIVE.md` | Create 原生外设速查（类型名/函数/事件/wiki 链接） | 本地整理 | — | 写代码第一入口 |
| `API_INSTANCE_ADDONS.md` | 本实例**额外**可用的外设与 ROM API（addon 提供） | 本地整理 | — | 写代码第一入口 |
| `API_CCCBridge.md` | CC:C Bridge 外设速查（**本实例未装**，仅参考） | 本地整理 | — | 加装后可用 |
| `_mods_scan.txt` | 生成物（**本地、不进版本库**）：mods 目录全量扫描（含每个 mod 的 id/version） | `scripts/scan_mods.py` | — | 环境证据 |
| `_instance_peripherals.txt` | 生成物（**本地、不进版本库**）：实例 CC 集成面（外设类型名/方法候选、ROM 附加、turtle 升级） | `scripts/dump_jar_peripherals.py` | — | 环境证据 |
| `_generated_peripherals.txt` | 生成物：Create 源码导出的外设清单基线 | `scripts/dump_create_peripherals.py` | — | 版本升级比对基准 |

> 克隆/更新时统一走加速前缀：`https://v6.gh-proxy.org/https://github.com/...`（见 `scripts/refresh_docs.py`）。

---

## 2. 问题 → 该看哪个文件（路由表）

| 我要知道…… | 看这个 |
|---|---|
| **这台机器上到底能调什么** | `ENVIRONMENT.md` → `API_INSTANCE_ADDONS.md` → `_instance_peripherals.txt` |
| 现场电脑实际连了哪些外设、类型名/方法是什么 | 让用户跑 `code/templates/probe_peripherals.lua`（脚本看不出来） |
| Create 有哪些原生 CC 外设、类型名字符串 | `API_CREATE_NATIVE.md` → 核对 `create-source/.../implementation/peripherals/*.java` 的 `getType()` |
| addon 提供的外设（Additional Logistics / Diesel Generators / Electro Energetics / Bits 'n' Bobs） | `API_INSTANCE_ADDONS.md`、`_instance_peripherals.txt` |
| CC: Sable 的 `aero`/`matrix`/`quaternion`/`sublevel`、`advanced_math.*` | `rom_extras/cc_sable/**`（真实文件）、`API_INSTANCE_ADDONS.md` §2 |
| turtle 升级 | `_instance_peripherals.txt` 的 `[turtle]` 段；CC:T 侧见 https://tweaked.cc/module/turtle.html |
| 某个 Create 外设的方法签名/参数/返回值 | `create-wiki/src/users/cc-tweaked-integration/**/*.md`（一外设一页） |
| 某个外设会发什么事件、参数是什么 | wiki 页面 “Events” 段 + 源码 `queueEvent(...)`（**参数顺序以源码为准**） |
| CC:T 自己的 API（`peripheral`/`fs`/`term`/`rednet`/`os`…） | 在线 https://tweaked.cc ；离线 `cc-tweaked/doc/**` 与 `cc-tweaked/projects/core/src/main/java/dan200/computercraft/core/apis/**` |
| Lua 语言版本 / 能用哪些语法 | `cc-tweaked/doc/reference/feature_compat.md`（Cobalt = Lua 5.2 语义 + 部分 5.3/5.0） |
| `require` 与模块路径怎么写 | `cc-tweaked/doc/guides/using_require.md` |
| 开机自启、启动文件规则 | `cc-tweaked/doc/reference/startup.md`、`cc-tweaked/doc/guides/startup.md` |
| 错误/异常模型（pcall、异常对象） | `cc-tweaked/doc/reference/exceptions.md` |
| 字符集 / 特殊字符显示（写中文、符号前必看） | `cccbridge/docs/guides/charset.md` |
| CC:C Bridge 有哪些外设（**本实例未装**） | `API_CCCBridge.md`、`cccbridge/docs/peripherals/*.md` |

### 各资料库关键路径速查

```
docs/ENVIRONMENT.md            ← 实测版本 / 已装未装 / 可用外设与 ROM API
docs/API_INSTANCE_ADDONS.md    ← 本实例 addon 外设 + ROM API 清单（含方法候选）
docs/rom_extras/cc_sable/      ← 抽出的真实 Lua 文件：apis/{aero,matrix,quaternion,sublevel}.lua
                                                   modules/main/advanced_math/{mmath,pid,stats}.lua
                                                   help/*.txt

docs/create-wiki/src/users/cc-tweaked-integration/
├── logistics/   packager, repackager, stock-ticker, redstone-requester, table-cloth,
│                package-frogport, postbox, package-object, order-data-object
├── train/       train-station, train-signal, train-observer, train-schedule, libraries
└── *.md         display-link, nixie-tube, sticker, sequenced-gearshift,
                 rotational-speed-controller, creative-motor, speedometer, stressometer

docs/create-source/src/main/java/com/simibubi/create/
├── compat/computercraft/                    ← CC 兼容层：每个外设的 getType() 与 @LuaFunction
│   └── implementation/peripherals/*.java
├── content/logistics/                       ← 物流内部实现（理解"Create 自己怎么读库存"）
│   ├── packager/PackagerBlockEntity.java    ← getAvailableItems()：把相邻 IItemHandler 压成 InventorySummary
│   ├── packager/InventorySummary.java       ← 物品→数量 的合并结构（含 ∞ / 组件区分）
│   ├── packagerLink/LogisticsManager.java   ← 按频率汇总网络库存 + 两级缓存（1 tick / 20 tick）
│   ├── packagerLink/LogisticallyLinkedBehaviour.java ← freqId 全局弱引用注册表（"网络"的本体）
│   ├── factoryBoard/FactoryPanelBehaviour.java ← 工厂仪表：getLevelInStorage() = 缓存摘要里数一数
│   └── stockTicker/StockCheckingBlockEntity.java ← 库存查询器的 getAccurateSummary/getRecentSummary
└── foundation/blockEntity/behaviour/inventory/  ← 相邻库存的 capability 读取行为

docs/cc-tweaked/
├── doc/events/*.md        CC:T 全部事件
├── doc/guides/*.md        gps_setup, local_ips, speaker_audio, startup, using_require
├── doc/reference/*.md     breaking_changes, feature_compat, exceptions, startup, command, data_pack …
├── doc/stub/{global,os,turtle}.lua
└── projects/core/src/main/java/dan200/computercraft/core/apis/**   ← 模块 API 的 javadoc 源头

docs/cccbridge/
├── docs/peripherals/{SourceBlock,TargetBlock,RedRouterBlock,ScrollerBlock,Animatronic}Peripheral.md
├── docs/guides/{charset,wrenches,positioningAnimatronic*,index}.md
└── neoforge|fabric/src/main/java/dev/kleinbox/cccbridge/common/computercraft/peripherals/*.java
```

---

## 3. 版本矩阵（**以实测为准**）

| 组件 | 实测值 | 备注 |
|---|---|---|
| 整合包 | Mechanomania 1.1.12.0 | 201 个 jar |
| Minecraft | 1.21.1 | |
| 加载器 | **NeoForge 21.1.248** | 1.21.1 上 Create 官方只有 NeoForge；Create Fabric 停在 1.20.1 |
| Create | **6.0.10** | 18 个原生 CC 外设 |
| CC: Tweaked | **1.120.2** | 文件名带 `-forge-`，实为 NeoForge 构建 |
| CC:C Bridge | **未安装** | 上游最新为 1.7.3（仅 NeoForge 1.21.1）；装了才有 `create_source` 等 |
| 其它 CC 集成 | **6 个 mod** | Additional Logistics、Bits 'n' Bobs、Diesel Generators、Electro Energetics、CC: Sable、Create Ore Excavation |
| 未装（可选） | CCCCC、CC:LiftLink、cbcperipheral/CC:CBC、CC: Create Compat+ | 只在用户确认装了时才允许依赖 |

> 版本不同 → API 可能不同。用户报的版本与本表/`ENVIRONMENT.md` 不一致时，**先停下来问**，不要"猜着兼容"。

---

## 4. 资料更新方式

脚本位于 `scripts/`，**Python 3，无第三方依赖**（Windows 下用 `python` 或 `py` 均可）。
用法与退出码见 `scripts/README.md`。

### 4.1 换版本 / 换整合包后（最重要）

```bat
:: 重扫用户实例：mod 列表 + 版本
python scripts\scan_mods.py --mods "<实例>\mods" --out docs\_mods_scan.txt

:: 重挖 CC 集成面（外设类型名/方法候选、ROM 附加、turtle 升级），并抽出附加 Lua API
python scripts\dump_jar_peripherals.py --mods "<实例>\mods" --extract-rom docs\rom_extras --out docs\_instance_peripherals.txt
```

然后把要点写进 `docs/ENVIRONMENT.md`（版本、已装/未装、外设与 ROM API 变化），并据此修订 `AGENTS.md` 第 1 节。

### 4.2 刷新上游资料快照

```bat
python scripts\refresh_docs.py                              :: 全量刷新（fetch + reset，保持 sparse）
python scripts\refresh_docs.py --proxy https://v6.gh-proxy.org/
python scripts\dump_create_peripherals.py --out docs\_generated_peripherals.txt   :: 与 API_CREATE_NATIVE.md 比对
```

刷新后必须：
1. 用 `dump_create_peripherals.py` 的输出与 `API_CREATE_NATIVE.md` 对比差异；
2. 在 `docs/INDEX.md`（本文件）更新 commit 与日期；
3. 在受影响项目的 `CHANGELOG.md` 注明"因版本升级复核了哪些 API"。
