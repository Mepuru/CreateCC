# Create 原生 CC: Tweaked 外设速查（1.21.1 / Create 6.0.x）

本表由源码自动提取，提取脚本 `scripts/dump_create_peripherals.py`（Python 3）。
**方法名来自 `@LuaFunction` 标注，类型名来自 `getType()`**，出处：
`docs/create-source/src/main/java/com/simibubi/create/compat/computercraft/implementation/peripherals/*.java`（分支 `mc1.21.1/dev`）。

- 语义、参数、返回值、事件说明：看同目录下 wiki 页面（下表 "wiki" 列，相对 `docs/create-wiki/src/users/cc-tweaked-integration/`）。
- ⚠️ 表里的函数名是自动提取的，可能漏掉个别重载；**写代码前请对照 java 文件确认**。
- ⚠️ 类型名字符串**区分大小写**，`Create_` 前缀是必须的。

```lua
local name, station = peripheral.find("Create_Station")
if not station then error("没有找到 Create_Station 外设，检查电脑是否贴着列车站") end
print(name, station.getStationName())
```

## 外设一览

| 类型名（Lua 里用） | 对应方块 | Lua 函数 | 事件 | wiki |
|---|---|---|---|---|
| `Create_Station` | 列车站 | `assemble` `disassemble` `setAssemblyMode` `isInAssemblyMode` `getStationName` `setStationName` `isTrainPresent` `isTrainImminent` `isTrainEnroute` `getTrainName` `setTrainName` `hasSchedule` `getSchedule` `setSchedule` `canTrainReach` `distanceTo` | `train_imminent` `train_arrival` `train_departure` | `train/train-station.md` |
| `Create_Signal` | 列车信号 | `getState` `isForcedRed` `setForcedRed` `listBlockingTrainNames` `getSignalType` `cycleSignalType` | `train_signal_state_change` | `train/train-signal.md` |
| `Create_TrainObserver` | 列车观察器 | `isTrainPassing` `getPassingTrainName` | `train_passing` `train_passed` | `train/train-observer.md` |
| `Create_Frogport` | 蛙港 | `setAddress` `getAddress` `getConfiguration` `setConfiguration` `list` `getItemDetail` | `package_sent` `package_received` | `logistics/package-frogport.md` |
| `Create_Postbox` | 邮筒 | `setAddress` `getAddress` `list` `getItemDetail` `getConfiguration` `setConfiguration` | `package_sent` `package_received` | `logistics/postbox.md` |
| `Create_Packager` | 打包机 | `makePackage` `getPackage` `list` `getItemDetail` `getAddress` `setAddress` | `package_created` `package_received` | `logistics/packager.md` |
| `Create_Repackager` | 再打包机 | `makePackage` `getPackage` `list` `getItemDetail` `getAddress` `setAddress` | `package_repackaged` `package_received` | `logistics/repackager.md` |
| `Create_StockTicker` | 库存查询器 | `stock` `getStockItemDetail` `requestFiltered` `list` `getItemDetail` | — | `logistics/stock-ticker.md` |
| `Create_RedstoneRequester` | 红石请求器 | `request` `setRequest` `setCraftingRequest` `getRequest` `getConfiguration` `setConfiguration` `setAddress` `getAddress` | — | `logistics/redstone-requester.md` |
| `Create_TableClothShop` | 桌面布（商店） | `isShop` `getAddress` `setAddress` `getPriceTagItem` `setPriceTagItem` `getPriceTagCount` `setPriceTagCount` `getWares` `setWares` | — | `logistics/table-cloth.md` |
| `Create_DisplayLink` | 显示链接 | `setCursorPos` `getCursorPos` `getSize` `isColor` `isColour` `write` `writeBytes` `clearLine` `clear` `update` | — | `display-link.md` |
| `Create_NixieTube` | 辉光管 | `setText` `setTextColour` `setTextColor` `setSignal` | — | `nixie-tube.md` |
| `Create_Sticker` | 贴纸 | `isExtended` `isAttachedToBlock` `extend` `retract` `toggle` | — | `sticker.md` |
| `Create_SequencedGearshift` | 序列齿轮箱 | `rotate` `move` `isRunning` | — | `sequenced-gearshift.md` |
| `Create_RotationSpeedController` | 转速控制器 | `setTargetSpeed` `getTargetSpeed` | — | `rotational-speed-controller.md` |
| `Create_Speedometer` | 转速表 | `getSpeed` | `speed_change` | `speedometer.md` |
| `Create_Stressometer` | 应力表 | `getStress` `getStressCapacity` | `overstressed` `stress_change` | `stressometer.md` |
| `Create_CreativeMotor` | 创造马达 | `setGeneratedSpeed` `getGeneratedSpeed` | — | `creative-motor.md` |

## Lua 侧的对象（不是外设，由方法/事件返回）

| 对象 | 获取方式 | 文档 |
|---|---|---|
| Package 对象（`getAddress` `setAddress` `list` `getItemDetail` `getOrderData` `isValid`） | `getPackage()`、`package_created`/`package_sent`/`package_received` 事件参数 | `logistics/package-object.md` |
| Order Data 对象 | Package 对象的 `getOrderData()` | `logistics/order-data-object.md` |
| 列车时刻表 table | `Create_Station.getSchedule()` / `setSchedule()` | `train/train-schedule.md`、`train/libraries.md` |

## ⚠️ 事件参数顺序（最容易踩的坑）

`SyncedPeripheral.queueEvent()` 会把**外设挂载名（attachment name，即 `left`/`right`/… 或网络里的名字）作为事件第一个参数**，
再拼上事件自身参数。源码 `SyncedPeripheral.java` 第 65–78 行的 javadoc 原文：

> Queue an event to all attached computers. Adds the peripheral attachment name as 1st event argument,
> followed by any optional arguments passed to this method.

wiki 的 train-signal 示例也印证：`local event, side, status = os.pullEvent("train_signal_state_change")`。

所以正确写法通常是：

```lua
-- 不要写成 2 个返回值；第一个是外设名
local event, side, stationName, trainName = os.pullEvent("train_arrival")
```

wiki 页面的 "Returns" 列表写的只是**事件自身参数**（如 station 名、train 名），不含前面的外设名。
写代码前：**以源码 `queueEvent(...)` 调用点为准**，必要时在游戏里 `print` 一次实际参数个数。

## 已发现的两处文档不一致（以事件段落 / 源码为准）

1. `speedometer.md` 的表格把事件写成 `speed`，事件段落与源码是 `speed_change`。
2. `cccbridge` 文档示例里有笔误（`peripheral.fid`、`setLocked`），见 `API_CCCBridge.md`。

---

# 按「要读什么」找外设（读取速查，零额外 mod）

用 Create 原生组件读数时，可用面有 **四种**，全部不需要装 CC:C Bridge：

## 1. Create 专用外设（最精确）

| 想读的 | 外设类型名 | 方法 / 事件 |
|---|---|---|
| 动力网络转速 | `Create_Speedometer` | `getSpeed()`；事件 `speed_change` |
| 应力占用 / 上限 | `Create_Stressometer` | `getStress()` `getStressCapacity()`；事件 `stress_change`、`overstressed` |
| 车站/列车状态、时刻表 | `Create_Station` | `isTrainPresent` `isTrainImminent` `isTrainEnroute` `getTrainName` `getStationName` `getSchedule` `canTrainReach` `distanceTo`；事件 `train_imminent` `train_arrival` `train_departure` |
| 信号状态 | `Create_Signal` | `getState()` `isForcedRed()` `getSignalType()` `listBlockingTrainNames()`；事件 `train_signal_state_change` |
| 列车经过检测 | `Create_TrainObserver` | `isTrainPassing()` `getPassingTrainName()`；事件 `train_passing` `train_passed` |
| **整个库存网络**的物品 | `Create_StockTicker` | `stock(item)` `getStockItemDetail()` `list()` `getItemDetail()` `requestFiltered()` |
| 蛙港/邮筒/打包机/再打包机内的物品与地址 | `Create_Frogport` `Create_Postbox` `Create_Packager` `Create_Repackager` | `list()` `getItemDetail()` `getAddress()` `getPackage()` `getConfiguration()`；事件 `package_created` `package_sent` `package_received` `package_repackaged` |
| 包裹内容 / 订单数据 | Package 对象、Order Data 对象 | `getAddress()` `list()` `getItemDetail()` `getOrderData()` |
| 红石请求器配置 | `Create_RedstoneRequester` | `getRequest()` `getConfiguration()` `getAddress()` |
| 商店（桌面布）信息 | `Create_TableClothShop` | `isShop()` `getWares()` `getPriceTagItem()` `getPriceTagCount()` |
| 齿轮箱/贴纸/马达/转速控制器状态 | `Create_SequencedGearshift` `Create_Sticker` `Create_CreativeMotor` `Create_RotationSpeedController` | `isRunning()` / `isExtended()` `isAttachedToBlock()` / `getGeneratedSpeed()` / `getTargetSpeed()` |

## 2. CC:T **通用外设**（读任意暴露"能力"的方块，含 Create 的容器/储罐）

| 类型名 | 能读什么 | 方法 | 文档 |
|---|---|---|---|
| `inventory` | 任何暴露**物品能力**的方块：Create 仓库/保险库、搅拌盆、溜槽、储物箱、传送带上的容器… | `list()` `getItemDetail(slot)` `size()` `pushItems`/`pullItems` | https://tweaked.cc/generic_peripheral/inventory.html |
| `fluid_storage` | 任何暴露**流体能力**的方块：Create 流体储罐、储液桶… | `tanks()`（+`pushFluid`/`pullFluid`） | https://tweaked.cc/generic_peripheral/fluid_storage.html |
| `energy_storage` | 暴露 FE 能量的方块（Create 本体没有，Create Crafts & Additions 之类才有） | `getEnergy()` `getEnergyCapacity()` | https://tweaked.cc/generic_peripheral/energy_storage.html |

```lua
-- 读贴着的 Create 流体储罐
local tank = peripheral.find("fluid_storage")
if tank then
  for i, t in pairs(tank.tanks()) do print(i, t.name, t.amount) end
end
-- 读贴着的容器
local inv = peripheral.find("inventory")
if inv then for i, it in pairs(inv.list()) do print(i, it.name, it.count) end end
```

> 类型名已在本实例的 CC:T 1.120.2 jar 中确认（`AbstractInventoryMethods`→`inventory`、
> `AbstractFluidMethods`→`fluid_storage`、`AbstractEnergyMethods`→`energy_storage`）。
> **能否读到具体方块，取决于该方块是否暴露对应能力**——Create 的储罐/容器通常会，
> 但必须用 `code/templates/probe_peripherals.lua` 实测确认。

## 3. CC:T 自带 `redstone_relay`（读任意红石模拟输出）

Create 的**阈值开关 / 仪表盘 / 各类仪表的红石输出**都能变成数字读进来，精度 0–15：

```lua
local relay = peripheral.find("redstone_relay")
print(relay.getAnalogInput("left"))  -- 0..15；也支持 getInput/getOutput/setAnalogOutput…
```

文档：https://tweaked.cc/peripheral/redstone_relay.html （CC:T **1.114.0** 起，本实例 1.120.2 有）。

## 4. 事件驱动（不用轮询）

`speed_change`、`stress_change`、`overstressed`、`train_*`、`package_*`、`train_signal_state_change`
——用 `os.pullEvent("...")` 直接等（注意 Create 原生外设事件第 1 个参数是外设挂载名）。

## 读不到的（原版方案确实没有）

Create 的**内部逻辑量**：烈焰燃烧器热度、蒸汽引擎状态、机器加工进度、工厂仪表盘（Factory Gauge）数值、
蓝图/合成器内部状态等——既没有专用外设，也没有通用能力接口。
CC:C Bridge **也读不到这些**（它只提供 Source/Target/RedRouter/Scroller/Animatronic）；
只有 `create_target`（冒充 Display Target 接收 Display Source 的数据）能间接抓到仪表显示的数值文本。

---

# 用 CC 替代工厂仪表（控制器模式）

工厂仪表 = **读库存 + 比阈值 + 红石输出 + （配补货打包机时）自动下单**。这四件事 CC 都能做，
而且能做得更细（一块仪表只能盯 1 种物品，一台电脑能盯 N 种）。分五层：

| 层 | 用什么 | 说明 |
|---|---|---|
| 传感 | `Create_StockTicker.stock()`（整张仓库网络，1 tick 缓存）<br>`inventory` 通用外设（单个容器/缓冲仓）<br>`Create_Speedometer`/`Create_Stressometer`（动力状态） | 网络汇总只有 StockTicker 能读 |
| 决策 | 你自己的 Lua：每种物品 min/max、滞回、优先级、限流、预测 | 仪表做不到的部分 |
| 执行（红石） | 电脑自带 `redstone.setAnalogOutput(side, v)`；远距离用 `redstone_relay` | 等价于仪表面板的红石输出 |
| 执行（下单） | `Create_RedstoneRequester` 或 `Create_StockTicker.requestFiltered()` | 见下表 |
| 显示 | `Create_DisplayLink`（翻页屏/辉光管）、`monitor`、`term` | 替代仪表面板数值 |
| 持久化 | `fs` 写状态文件 + `startup.lua` 自启 | 重启后不丢"已下单"账本 |

## 两条下单 API（都原生、都不需要额外 mod）

```lua
-- A) 库存查询器直接下单（在库过滤式，可一次多组过滤）
--    signature: requestFiltered(address, filter1 [, filter2 ...]) -> 已发出数量
--    每个 filter 是 itemDetail 表；可选 "_requestCount" 限定数量
local n = ticker.requestFiltered("warehouse", { name = "minecraft:iron_ingot", _requestCount = 64 })

-- B) 红石请求器（可设物品+数量、可 autocraft、可 strict/allow_partial）
--    setRequest("id" | {name=,count=≤256}, ... 共 9 槽)   —— 普通请求
--    setCraftingRequest(批次数, "id", ... 共 9 槽)          —— 走网络自动合成
--    setAddress(addr) / setConfiguration("strict"|"allow_partial") / request()
requester.setAddress("warehouse")
requester.setConfiguration("strict")
requester.setCraftingRequest(2, "create:precision_mechanism")  -- 合成 2 批
requester.request()
```

出处：`docs/create-source/.../compat/computercraft/implementation/peripherals/RedstoneRequesterPeripheral.java`、
`StockTickerPeripheral.java`；文档 `create-wiki/.../logistics/redstone-requester.md`、`stock-ticker.md`。

## 与仪表的差距（替换时必须自己补上）

1. **"在途/promised" 读不到**：仪表的 `getPromised()` 来自内部 `RequestPromiseQueue`。
   CC 侧要自己记账：`request()` 后把数量记进状态文件，收到蛙港 `package_received`/`package_sent` 事件再核销。
2. **合成链依赖**：`setCraftingRequest` 依赖网络里有对应配方/合成能力；CC 无法查询配方，
   要靠用户给定或 `Create_StockTicker` 的库存反推。
3. **仪表之间的连线（生产计划 DAG）** 没有对应物——直接在你的 Lua 里实现（这本来就是升级点）。
4. **区块未加载的链接不计入汇总**，仪表会显示"等待网络"，CC 只会看到偏小的数字 → 程序里对
   "数值骤降"要做容错，或让仓库常驻加载。
5. **下单是异步的**：包要几秒才到。策略必须**幂等 + 冷却**，别每秒重复下单（会刷爆打包机队列）。
6. `stock()` 每次都返回整张网络的物品表，且是 `mainThread = true`（跑服务端主线程）→ **1–2 秒轮询一次**即可，别每 tick 调。


