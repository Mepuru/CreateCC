# scripts/ — 维护脚本（Python 3，无第三方依赖）

| 脚本 | 作用 |
|---|---|
| `refresh_docs.py` | 刷新 `docs/` 下 4 个上游资料库（`git fetch` + 重置到上游分支，保持 sparse 配置），走 gh-proxy 加速 |
| `dump_create_peripherals.py` | 从 Create 1.21.1 源码导出原生 CC 外设清单（类型名 / Lua 函数 / 事件），用于和 `docs/API_CREATE_NATIVE.md` 比对 |
| `scan_mods.py` | 扫描**用户实例的 mods 目录**：版本（从实例 json 读 MC/NeoForge）、全部 mod 的 id/version、哪些 mod 与 CC:T / Create 相关 |
| `dump_jar_peripherals.py` | 从 jar 里挖**实例实际可用的 CC:T 集成面**：外设类型名+方法候选、Lua ROM 附加（全局 API / require 模块）、turtle 升级；`--extract-rom` 可把附加 Lua 文件抽出来存档 |

## 用法

```bat
:: 刷新上游资料快照
python scripts\refresh_docs.py
python scripts\refresh_docs.py --proxy https://v6.gh-proxy.org/

:: Create 源码 → 外设清单基线
python scripts\dump_create_peripherals.py
python scripts\dump_create_peripherals.py --out docs\_generated_peripherals.txt

:: 扫描用户实例（换版本 / 换整合包后必跑）
python scripts\scan_mods.py --mods "<你的实例目录>\mods" --out docs\_mods_scan.txt
python scripts\scan_mods.py --mods <mods目录> --full --out docs\_mods_scan.txt

:: 挖实例的 CC 集成面，并把附加 Lua API 抽出来
python scripts\dump_jar_peripherals.py --mods <mods目录> --extract-rom docs\rom_extras --out docs\_instance_peripherals.txt
python scripts\dump_jar_peripherals.py <某个.jar>              :: 只分析单个 jar
::   --include-computercraft  连 CC:T 本体一起挖（默认跳过，输出很吵）
```

## 约定

- 退出码：`0` = 成功，`1` = 失败（信息打到 stderr），便于接进任何 CI / 批处理。
- 只依赖标准库（`argparse` / `subprocess` / `re` / `zipfile` / `json` / `pathlib`），不装任何包。
- 脚本路径以自身位置推导工程根目录（`Path(__file__).resolve().parents[1]`），可从任意工作目录调用。
  `scan_mods.py` / `dump_jar_peripherals.py` 需要显式 `--mods <实例mods目录>`。
- 输出统一 UTF-8（Windows 控制台会自动 `reconfigure`，避免中文报 `UnicodeEncodeError`）。
- 需要本机有 `git` 且在 `PATH` 里（只有 `refresh_docs.py` 需要）；失败时不会留下半成品分支（失败即报错退出）。
- jar 解析结论是**候选**：类型名/方法名要再用游戏内的 `code/templates/probe_peripherals.lua` 核实。
