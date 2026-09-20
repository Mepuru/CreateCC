# code/ — 代码工作区

所有交付给用户的 CC: Tweaked Lua 程序都写在这里。规范见仓库根目录 `AGENTS.md`。

## 目录约定

```
code/
├── lib/                 跨项目复用的库（改这里要评估影响范围）
├── create-native/       只依赖 Create 原生外设（无 CC:C Bridge）
├── cccbridge/           依赖 CC:C Bridge 外设
├── templates/           模板，不要直接当成品改
└── <project_name>/      一个用户任务一个目录
    ├── main.lua         入口程序
    ├── lib/             该项目私有库（可选）
    ├── README.md        ★ 部署说明：文件放哪、需要什么外设、怎么启动、已验证环境
    └── CHANGELOG.md     变更记录
```

- 目录名/文件名：小写 + 下划线，如 `train_dispatch/`、`train_dispatch.lua`；不要中文文件名。
- 每个项目必须有 `README.md`，其中必须写明**每个文件在游戏电脑里的绝对路径**（`require` 依赖相对路径正确）。

## 模板

| 模板 | 用途 |
|---|---|
| `templates/TASK_REQUEST.md` | 用户填写任务单（Agent 按 `AGENTS.md` 第 3 节索取信息时用这个） |
| `templates/program.lua` | 程序入口骨架：外设探测 + 事件循环 + pcall + terminate 清理 |
| `templates/lib.lua` | 库骨架：`local M = {}` … `return M` |
| `templates/probe_peripherals.lua` | **现场探测脚本**：电脑信息 + ROM 附加 API + 每个外设的类型名与方法列表；让用户跑一次并贴回输出 |

## 怎么把代码送进游戏电脑（交付时按用户情况选一种写进 README）

1. **手敲/粘贴**：直接在电脑里 `edit 文件名.lua`，用 Ctrl+V 粘贴（最简单，适合短程序）。
2. **磁盘/软盘**：`disk` 程序 + 电脑里的 `fs.copy("/disk/xxx.lua", "/xxx.lua")`。
3. **http 下载**（需服务器/单人允许 CC:T 的 http API）：把文件放到可访问的 URL，用 `wget <url> <path>`。
4. **pastebin**：`pastebin get <code> <path>`（同样需要 http）。

> 无论哪种方式，交付时都要给出**运行命令**（例如 `train_dispatch` 或 `lua train_dispatch.lua`）
> 以及**自启方式**（`startup.lua`，规则见 `docs/cc-tweaked/doc/reference/startup.md`）。
