# CC:C Bridge 外设速查（1.21.1 / v1.7.3）

> ⚠️ **用户当前实例没有安装 CC:C Bridge**（实测 2026-09-20，见 `ENVIRONMENT.md`）。
> 本文件只作为"将来加装这个 mod 之后"的参考；在这套装里写 `peripheral.find("create_source")` 之类**会失败**。
> 本实例实际可用的外设与 Lua API 见 `API_INSTANCE_ADDONS.md`。

CC:C Bridge（`cccbridge`）是**追加**在 Create 原生联动之上的兼容 mod：它补上 Create 原生没有的外设
（Source / Target / RedRouter / Scroller / Animatronic）。

- 类型名出处（源码 `getType()`）：
  `docs/cccbridge/neoforge/src/main/java/dev/kleinbox/cccbridge/common/computercraft/peripherals/*.java`
- 文档出处（该 mod 自带 mkdocs）：`docs/cccbridge/docs/peripherals/*.md`
- 前置：1.21.1 只有 **NeoForge** 构建；官方测试组合 CC:T `1.119.0` + Create `6.0.10-280`。

> ⚠️ 文档示例里有笔误：`peripheral.fid("scroller")`（应为 `peripheral.find`）、`scroller.setLocked(true)`
> （函数表里是 `setLock(state)`）。**以函数表 / 源码为准，不要照抄示例代码。**

## 外设一览

| 类型名（Lua 里用） | 方块 | 函数 / 事件 | 文档 |
|---|---|---|---|
| `create_source` | Source Block —— 把文本发给 Create 的显示目标（翻页屏、辉光管等） | 接口与 [Terminal](https://tweaked.cc/module/term.html) 基本一致：`getSize` `clear` `clearLine` `setCursorPos` `getCursorPos` `write` …；另有 `getLine(y)`。事件：`monitor_resize`（参数=外设名） | `docs/cccbridge/docs/peripherals/SourceBlockPeripheral.md` |
| `create_target` | Target Block —— 模拟 Create 的 Display Target，接收 Display Source 的数据 | `resize(width, height)` `getLine(y)` `dump()` `getSize()` | `.../TargetBlockPeripheral.md` |
| `redrouter` | RedRouter —— 收发红石信号（远距离一根线） | `setOutput(side, on)` `setAnalogOutput(side, value)` `getOutput(side)` `getInput(side)` `getAnalogOutput(side)` `getAnalogInput(side)`；事件见文档 "Events" | `.../RedRouterBlockPeripheral.md` |
| `scroller` | Scroller Pane —— 让玩家在世界里选一个数 | `isLocked()` `setLock(state)` `getValue()` `setValue(value)` `getLimit()` `setLimit(limit)` `hasMinusSpectrum()` `toggleMinusSpectrum(state)`；事件：`scroller_changed`（参数：外设名, 新值） | `.../ScrollerBlockPeripheral.md` |
| `animatronic` | Animatronic —— 机械玩偶（可动头/身/左右手 + 表情） | `setFace(face)` `setTransition(kind)` `push()` `setHeadRot(x,y,z)` `setBodyRot(x,y,z)` `setLeftArmRot(x,y,z)` `setRightArmRot(x,y,z)` `getStored*Rot()` `getApplied*Rot()` | `.../AnimatronicPeripheral.md` |

## attach 规则（源码文档里的 Metadata 段）

| 外设 | attach 名 | attach 面 |
|---|---|---|
| Source Block | `create_source` | 所有面 |
| Target Block | `create_target` | 所有面（见文档 Metadata） |
| RedRouter | `redrouter` | 见文档 Metadata |
| Scroller Pane | `scroller` | **仅 `"back"`**（需要在它背后接 modem） |
| Animatronic | `animatronic` | 见文档 Metadata |

## 与 Create 原生外设的分工

- Create 原生：列车（站/信号/观察器）、物流（打包/蛙港/邮筒/库存/请求器/桌面布）、显示与传动仪表。
- CC:C Bridge 追加：**自由文本推送到显示屏**（`create_source`）、**把 Create 数据接进电脑**（`create_target`）、
  远距离红石线（`redrouter`）、玩家数值输入（`scroller`）、机械玩偶（`animatronic`）。
- 两者**可以同时装**，外设名不冲突；实际项目里经常一起用（例：`create_target` 读转速 → 脚本判断 → `redrouter` 输出红石）。
