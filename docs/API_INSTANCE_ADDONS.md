# 本实例额外可用的 CC:T API（addon 提供）

除了 Create 原生 18 个外设（见 `API_CREATE_NATIVE.md`），这台机器上还有 **6 个 mod** 在给 CC:T 加东西。
本文件是这些"额外 API"的清单与出处；环境整体情况见 `ENVIRONMENT.md`。

> 证据来源：`scripts/dump_jar_peripherals.py` 直接解析各 jar 的 class 常量池 / 方法表 / ROM 文件，
> 原始输出在 `docs/_instance_peripherals.txt`。
> **类型名与方法名是"候选"**（脚本看不到注册逻辑），最终以游戏内为准——用
> `code/templates/probe_peripherals.lua` 探测一次即可确认。

---

## 1. 外设方块

| 类型名（Lua 里用） | 方法（候选） | 来源 mod | 版本 |
|---|---|---|---|
| `CreateAdditionalLogistics_CashRegister` | `getLedger` `getSales` `getTarget` | Create: Additional Logistics | 1.21.1-1.4.5 |
| `CreateAdditionalLogistics_PackageEditor` | `addRule` `applyRules` `clearRules` `getRule` `listRules` `resetRules` `setRule` `setRules` | Create: Additional Logistics | 1.21.1-1.4.5 |
| ⚠️ 类型名未提取到（方法为 `getStation` `getTrain` `listStations` `listTrains`） | — | Create: Additional Logistics（`NetworkMonitorPeripheral`） | 1.21.1-1.4.5 |
| `Create_Bits_N_Bobs_Headlamp` | `setLamp` | Create Bits 'n' Bobs（`bits_n_bobs`） | 2.2.7 |
| `CDG_ChemicalTurret` | `getHorizontalRotation` `getVerticalRotation` `setHorizontalRotation` `setVerticalRotation` `spray` | Create Diesel Generators | 1.21.1-1.3.15 |
| `ElectroEnergetics_ElectricGauge` | `getValue` | Create Electro Energetics | 1.21.1-1.1.1 |

用法与 Create 原生一致（类型名区分大小写）：

```lua
local editor = peripheral.find("CreateAdditionalLogistics_PackageEditor")
if not editor then error("没找到 PackageEditor，检查方块是否贴着电脑或接入 modem") end
print(peripheral.getName(editor), textutils.serialize(editor.listRules()))
```

> `NetworkMonitorPeripheral` 的类型名没被脚本抓到（它可能继承/拼接了类型名）。用 probe 脚本看它实际报什么。

## 2. Lua ROM 附加（**任何电脑都能直接用**）

来源：**CC: Sable 1.3.4**（`cc_sable-neoforge-1.3.4.jar`）。这些不是外设，而是直接注入 ROM 的
全局 API 与 `require` 模块——**不需要贴任何方块**。

已抽取的真实文件在 `docs/rom_extras/cc_sable/`（`apis/` 全局 API、`modules/` 模块、`help/` 帮助文本）。

### 2.1 全局 API

| 全局名 | 函数 | 说明 |
|---|---|---|
| `aero` | `getAirPressure` `getGravity` `getMagneticNorth` `getUniversalDrag` `getRaw` `getDefault` | 维度物理信息（气压/重力/磁北/阻力） |
| `matrix` | `new` `identity` `fromVector` `fromQuaternion` `from2DArray` `solve` | 矩阵运算 |
| `quaternion` | `new` `identity` `fromAxisAngle` `fromComponents` `fromEuler` `fromMatrix` `fromShip` | 四元数（姿态/旋转） |
| `sublevel` | `getUniqueId` `getName` `setName` `getMass` `getInverseMass` `getCenterOfMass` `getInertiaTensor` `getInverseInertiaTensor` `getLinearVelocity` `getAngularVelocity` `getVelocity` `getLastPose` `getLogicalPose` `isInPlotGrid` | Sable 物理子层级（飞船/装置）状态读写 |

```lua
-- 例：读当前维度的重力方向
local g = aero.getGravity()
print(("gravity = (%.2f, %.2f, %.2f)"):format(g.x, g.y, g.z))
```

### 2.2 `require` 模块

| 模块 | 内容 |
|---|---|
| `advanced_math.mmath` | `solveRoot` `solveSysEq` `integrateSimple` `integrateComplex` `weightedTable` `scramble` `ARC` |
| `advanced_math.pid` | `new`（PID 控制器） |
| `advanced_math.stats` | 统计库：`mean` `median` `mode` `stdev` `variance` `percentile` `quartiles` `iqr` `outliers` `correlation` `covariance` `linReg` `linRegPred` `linRegTTest` `tCDF` `normalCDF` `oneSampleTTest` `pairTTest` `twoSampleTTest` `gini` `kurtosis` `skewness` … |

```lua
local stats = require("advanced_math.stats")
print(stats.mean({ 1, 2, 3, 4 }))
local pid = require("advanced_math.pid").new(1, 0.1, 0.05)
```

> `require` 走 `package.path`（`?/init.lua` 等），**不是**文件路径；详见
> `docs/cc-tweaked/doc/guides/using_require.md`。

## 3. turtle 升级

| 升级 | 来源 mod |
|---|---|
| `createoreexcavation:vein_finder` | Create Ore Excavation 1.21.1-1.6.8 |

（turtle 相关的 Lua 面见 `docs/cc-tweaked/doc/stub/turtle.lua` 与 https://tweaked.cc/module/turtle.html 。）

## 4. 注意事项

1. **别把这些当成 CC:T 通用能力**：它们是这套整合包的 mod 带来的。换整合包/服务端没装，就会 `nil` 报错。
   跨环境要用的程序，启动时先探测（`if not aero then ... end` / `pcall(require, "...")`）。
2. ROM 全局 API 与 **CC:T 版本**绑定（`data/computercraft/lua/rom/...` 由 CC:T 加载）。升级 CC:T 后重跑扫描。
3. `docs/API_CCCBridge.md` 里的 `create_source` / `create_target` / `redrouter` / `scroller` / `animatronic`
   在本实例**不存在**（未装 CC:C Bridge）。
