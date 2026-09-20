# 实测环境快照（用户当前实例）

> 本文件是**真实环境**的记录，优先级高于 `AGENTS.md` 第 1 节的"目标版本矩阵"。
> 写代码前以本文件为准；它过期了就重新跑扫描脚本（见文末）。
>
> 扫描时间：2026-09-20 ｜ 工具：`scripts/scan_mods.py` + `scripts/dump_jar_peripherals.py`

## 1. 客户端实例

| 项 | 值 |
|---|---|
| 整合包 | Mechanomania 1.1.12.0 |
| 实例目录 | `<你的实例目录>`（例如 `.minecraft\versions\<整合包名>`；本仓库不记录具体路径） |
| mods 目录 | `<实例目录>\mods`（实测时 **201 个 jar**，约 389 MB） |
| Minecraft | **1.21.1** |
| 加载器 | **NeoForge 21.1.248** |
| Create | **6.0.10**（`create-1.21.1-6.0.10.jar`） |
| CC: Tweaked | **1.120.2**（`[CC：Tweaked] cc-tweaked-1.21.1-forge-1.120.2.jar`；文件名带 `-forge-`，实际是 NeoForge 构建） |

> ⚠️ 这是**客户端**目录。CC 电脑与外设由**服务端**提供逻辑；联机时服务端必须装同样的 mod，
> 单机（内置服务器）则等于本目录。写依赖某 mod 的程序前，先确认"服务端也有它"。

## 2. 这台机器上真正的 CC:T 集成面（三个来源，缺一不可）

`AGENTS.md` 原来只讲了"Create 原生外设 + CC:C Bridge"，实测**不止**——这套包里有 6 个 mod 在给 CC:T 加东西：

### 2.1 外设方块（`peripheral.find("X")`）

| 类型名 | 来源 mod | 版本 |
|---|---|---|
| `Create_Station` / `Create_Signal` / `Create_TrainObserver` / `Create_Frogport` / `Create_Postbox` / `Create_Packager` / `Create_Repackager` / `Create_StockTicker` / `Create_RedstoneRequester` / `Create_TableClothShop` / `Create_DisplayLink` / `Create_NixieTube` / `Create_Sticker` / `Create_SequencedGearshift` / `Create_RotationSpeedController` / `Create_Speedometer` / `Create_Stressometer` / `Create_CreativeMotor` | Create（原生，18 个） | 6.0.10 |
| `CreateAdditionalLogistics_CashRegister`、`CreateAdditionalLogistics_PackageEditor` | Create: Additional Logistics | 1.21.1-1.4.5 |
| `Create_Bits_N_Bobs_Headlamp` | Create Bits 'n' Bobs | 2.2.7 |
| `CDG_ChemicalTurret` | Create Diesel Generators | 1.21.1-1.3.15 |
| `ElectroEnergetics_ElectricGauge` | Create Electro Energetics | 1.21.1-1.1.1 |
| （类型名未提取到，需游戏内核实）`NetworkMonitorPeripheral` | Create: Additional Logistics | 1.21.1-1.4.5 |

明细与证据类名见 `API_INSTANCE_ADDONS.md`。

### 2.2 Lua ROM 附加（**新全局 API + 新 require 模块**）

由 **CC: Sable 1.3.4** 注入，任何一台电脑上都能直接用：

- 全局 API：`aero`、`matrix`、`quaternion`、`sublevel`
- `require` 模块：`advanced_math.mmath`、`advanced_math.pid`、`advanced_math.stats`
- 已抽取成文本放在 `docs/rom_extras/cc_sable/`（`apis/`、`modules/`、`help/`），可直接读真实签名

### 2.3 turtle 升级

| 升级 id | 来源 mod | 版本 |
|---|---|---|
| `createoreexcavation:vein_finder` | Create Ore Excavation | 1.21.1-1.6.8 |

### 2.4 显示能力：**只能显示 ASCII**（实测乱码，重要）

CC:T 的终端/显示器只渲染它自带的那张位图字体，jar 内唯一字体资源是
`assets/computercraft/textures/gui/term_font.png`，**没有任何 Unicode / unifont 字形提供器**
（全 jar 里搜 `unifont|unicode|glyph` 无结果）→ **汉字画不出来，实测乱码**。

因此：

- 所有 `print` / `log` / 写到屏幕的文本**一律 ASCII**（英文、数字、符号）。
- 中文只允许出现在：① 代码注释与文档 ② **数据字符串**（例如物流地址 `address = "经验"`，
  它只参与比较、不绘制）。
- `config.display.title`、`rule.label` 这类会显示的字段也必须 ASCII。

**摆放**：用户实例的显示器在电脑**右侧**；程序用 `peripheral.find("monitor")` 按类型自动定位，
不写死侧面。右侧被显示器占用，所以红石默认输出到空闲的 `left` 面。

## 3. 本实例**没有**装的 CC 相关 mod（别写依赖它们的代码）

`CC:C Bridge`（`cccbridge`）、`CCCCC`（装置上的电脑）、`CC:LiftLink`、`cbcperipheral` / `CC:CBC`（火炮）、
`CC: Create Compat+`、`CC: Redstone Link Gateway/Redstone Link Bridge`。

- `docs/API_CCCBridge.md` 仍然保留，但**只作为"将来装了之后"的参考**；在本实例里
  `peripheral.find("create_source")` 之类会失败。
- 需要"把文本推到显示屏""读 Create 数据到电脑"这类 CC:C Bridge 才有的能力时，先问用户是否愿意加装。

## 4. 与 `AGENTS.md` 第 1 节版本矩阵的差异（已同步修订）

| 项 | 原矩阵 | 实测 |
|---|---|---|
| CC: Tweaked | 1.119.0 / 1.120.x | **1.120.2** |
| NeoForge | 未记 | **21.1.248** |
| CC:C Bridge | "可选但常见" | **未安装** |
| 其他 CC 集成提供方 | 未记 | **6 个 mod**（Additional Logistics / Bits 'n' Bobs / Diesel Generators / Electro Energetics / CC: Sable / Create Ore Excavation） |
| 整合包 | 未记 | Mechanomania 1.1.12.0（201 mods，KubeJS + FTB Quests 在列） |

## 5. 怎么刷新这份快照

```bat
:: 1) mod 列表 + 版本（含 MC/NeoForge）
python scripts\scan_mods.py --mods "<你的实例目录>\mods" --out docs\_mods_scan.txt

:: 2) 实例实际可用的外设 / ROM API / turtle 升级，并把附加 Lua API 抽出来存档
python scripts\dump_jar_peripherals.py --mods "<你的实例目录>\mods" --extract-rom docs\rom_extras --out docs\_instance_peripherals.txt
```

（两份生成物：`docs/_mods_scan.txt`、`docs/_instance_peripherals.txt`；升级 mod 后重跑并更新本文件。）

## 6. 仍然必须由用户在游戏内确认的两件事

脚本只能看到 jar 里"写了什么"，看不到"世界里放了什么"：

```lua
-- 电脑实际连着哪些外设、类型名到底是什么
for _, n in ipairs(peripheral.getNames()) do print(n, peripheral.getType(n)) end
-- 装了哪些全局 API / 模块（CC: Sable 提供）
print(aero, matrix, quaternion, sublevel)
print(pcall(require, "advanced_math.stats"))
```
