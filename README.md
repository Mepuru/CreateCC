# CreateCC — Create × CC: Tweaked 开发资料库与代码区

给 **Minecraft 1.21.1（NeoForge）+ Create 6.0.x + CC: Tweaked** 写 Lua 程序时用的"离线规范 + 代码工作区"。

**当前实测环境**（Mechanomania 1.1.12.0）：MC 1.21.1 ｜ NeoForge 21.1.248 ｜ Create 6.0.10 ｜ CC:T 1.120.2 ｜
**未装 CC:C Bridge** ｜ 另有 6 个 mod 提供 CC 集成面（含 CC: Sable 注入的 `aero`/`matrix`/`quaternion`/`sublevel`）。
详见 `docs/ENVIRONMENT.md`。

## 目录

| 路径 | 作用 |
|---|---|
| `AGENTS.md` | **给 Agent 的规范**：探环境、资料使用规则、必须向用户索取的信息、编码规范、工作流程、常见坑 |
| `docs/ENVIRONMENT.md` | **实测环境快照**：版本、已装/未装、实际可用的外设与 Lua API（写代码前先读） |
| `docs/` | 一手资料快照（Create 官方 wiki、Create 1.21.1 CC 兼容源码、CC:T 文档与源码、CC:C Bridge 源码+文档） |
| `docs/INDEX.md` | 资料地图：问题→文件路由表 + 版本矩阵 + 更新方式 |
| `docs/API_CREATE_NATIVE.md` | Create 原生 CC 外设速查（18 个：类型名 / 函数 / 事件 / 文档链接） |
| `docs/API_INSTANCE_ADDONS.md` | 本实例**额外**可用的外设与 ROM API（addon 提供） |
| `docs/API_CCCBridge.md` | CC:C Bridge 外设速查（**本实例未装**，仅参考） |
| `code/` | **写代码的地方**（项目目录、共享库、模板） |
| `code/stock_controller/` | **已交付的项目**：用 CC 电脑替代工厂仪表（盯虫蚀石砖、红石请求器下单、CC 显示器看板）——安装见其 `INSTALL.md` |
| `scripts/` | Python 3 维护脚本（资料刷新 / 实例扫描 / 外设导出），用法见 `scripts/README.md` |

## 首次使用（刚克隆本仓库）

上游资料库（`docs/create-wiki`、`docs/create-source`、`docs/cc-tweaked`、`docs/cccbridge`）与
`docs/rom_extras/` 都**不进版本库**（第三方内容、体积大、可按需重建）。克隆后先跑：

```bat
:: 1) 拉回上游资料快照（4 个仓库，走 gh-proxy 加速，约十几 MB）
python scripts\refresh_docs.py

:: 2) 重新导出 Create 外设清单基线（与 docs/API_CREATE_NATIVE.md 比对用）
python scripts\dump_create_peripherals.py > docs\_generated_peripherals.txt
```

然后**先读 `docs/ENVIRONMENT.md` 和 `AGENTS.md`**——前者是实测环境，后者是工作规范。
如果要针对自己那台机器重新扫描，用 `scripts/scan_mods.py` / `scripts/dump_jar_peripherals.py`（见 `scripts/README.md`）。

## 30 秒上手

```bat
:: 0) 环境变了才需要：重扫用户实例（mod 列表 + 实际可用的 CC 集成面）
python D:\WorkSpace\CreateCC\scripts\scan_mods.py --mods "D:\Minecraft\.minecraft\versions\Mechanomania-1.1.12.0\mods" > D:\WorkSpace\CreateCC\docs\_mods_scan.txt
python D:\WorkSpace\CreateCC\scripts\dump_jar_peripherals.py --mods "D:\Minecraft\.minecraft\versions\Mechanomania-1.1.12.0\mods" --extract-rom D:\WorkSpace\CreateCC\docs\rom_extras > D:\WorkSpace\CreateCC\docs\_instance_peripherals.txt

:: 1) 可选：刷新上游资料快照（走 gh-proxy 加速）
python D:\WorkSpace\CreateCC\scripts\refresh_docs.py

:: 2) 让 Agent 干活：把任务单填好丢给它
notepad D:\WorkSpace\CreateCC\code\templates\TASK_REQUEST.md
::    → 复制成 code\<项目名>\TASK_REQUEST.md 并填写

:: 3) Agent 的产出在 code\<项目名>\ ，按 README.md 里的路径拷进游戏电脑
```

## 游戏内确认现场（每次开工先跑这段）

最省事的做法：把 `code/templates/probe_peripherals.lua` 拷进电脑跑一次，它会把
"电脑 id / ROM 附加 API 是否存在 / 每个外设的挂载名+类型名+方法列表"全部打印出来。

最小版本（只要外设类型名）：

```lua
for _, n in ipairs(peripheral.getNames()) do
  print(n, peripheral.getType(n))
end
```

把输出贴给 Agent，能省掉大部分来回猜测。
