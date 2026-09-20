# 任务单（用户填写 → 交给 Agent）

> 复制本文件到 `code/<项目名>/TASK_REQUEST.md` 并填写。**不确定的项写"不确定"**，Agent 会来问。
> 这份表对应 `AGENTS.md` 第 3 节的交接清单；填得越全，来回越少。

## 0. 环境扫描（Agent 先跑，用户补游戏内探测）

Agent 侧（只在换版本/换整合包后需要）：
```bat
python scripts\scan_mods.py --mods "<实例>\mods" > docs\_mods_scan.txt
python scripts\dump_jar_peripherals.py --mods "<实例>\mods" --extract-rom docs\rom_extras > docs\_instance_peripherals.txt
```
当前已知实例（`docs/ENVIRONMENT.md`）：Mechanomania 1.1.12.0 ｜ MC 1.21.1 ｜ NeoForge 21.1.248 ｜
Create 6.0.10 ｜ CC:T 1.120.2 ｜ 未装 CC:C Bridge。

用户侧（**必须**）：把 `code/templates/probe_peripherals.lua` 拷进目标电脑运行，把输出贴到下面：
```
（把 probe_peripherals 的完整输出贴这里）
```

## 1. 一句话目标

（例：让列车到站时在显示屏上显示车次，并把站台灯变绿）

## 2. 环境版本（必填）

| 项 | 值 |
|---|---|
| Minecraft | （例：1.21.1） |
| 加载器 | （NeoForge / 其他 + 版本） |
| Create 版本 | （例：6.0.10） |
| CC: Tweaked 版本 | （例：1.119.0） |
| CC:C Bridge | （装了 / 没装 + 版本） |
| 其他相关 mod | （CCCCC / 火炮 / Power Grid / Aeronautics / 无） |
| 单人 / 服务器 | （服务器的话：能否改配置、是否允许 http API） |

## 3. 现场硬件（必填，最关键）

| 项 | 值 |
|---|---|
| 电脑种类与数量 | （普通 / 高级 / 命令电脑；共几台） |
| 电脑在游戏里的位置/名字 | |
| 是否有显示器 / 扬声器 | |

### 3.1 外设探测结果（请在游戏里跑完贴回来）

推荐：把 `code/templates/probe_peripherals.lua` 拷进电脑运行 `probe_peripherals`，它会同时给出
**挂载名 / 类型名 / 方法列表 / ROM 附加 API 是否存在**。最小版本：

```lua
for _, n in ipairs(peripheral.getNames()) do print(n, peripheral.getType(n)) end
```

粘贴输出：

```
（把输出贴这里）
```

### 3.2 外设安装位置

（例：列车站贴在电脑 `right` 面；显示屏通过有线 modem 连在同一网络）

## 4. 通信拓扑

| 项 | 值 |
|---|---|
| 有线 / 无线 modem | |
| 频道号（如用 rednet） | |
| 是否需要 GPS | |
| 多台电脑分工 | （例：A 机采集 → 广播；B 机显示） |
| 区块是否常驻加载 | |

## 5. 功能细节

| 项 | 值 |
|---|---|
| 触发方式 | （事件驱动 / 定时轮询 / 玩家点击屏幕） |
| 输入 | （读哪个数值、来自哪个外设/事件） |
| 输出 | （写到哪块屏 / 哪个红石面 / 发什么消息） |
| 异常时的行为 | （重试 / 报警 / 停机 / 打印日志） |
| 频率或精度要求 | （每 tick / 每秒 / 每分钟） |
| 需要持久化状态吗 | （重启后要不要恢复） |
| 需要开机自启吗 | （要 → 会交付 `startup.lua`） |
| 会贴中文/特殊符号吗 | （会影响字符集注意事项） |

## 6. 交付要求

| 项 | 值 |
|---|---|
| 代码在电脑里的目标路径 | （例：`/create_cc/train.lua`） |
| 单文件 / 多文件 | |
| 注释与文档语言 | （中文 / 英文） |
| 命名偏好 | （可选） |

## 7. 验收场景（Agent 会照这个写验证步骤）

1. 用户会怎么操作：
2. 期望看到什么：
3. 什么情况算失败：

## 8. 失败时可以提供的信息

- [ ] 报错全文（截图或复制终端文字）
- [ ] 第 3.1 节的外设探测输出
- [ ] `os.version()` 的输出
- [ ] 相关 mod 的文件名/版本截图
