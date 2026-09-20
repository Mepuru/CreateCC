# code/lib/ — 跨项目共享库

放多个项目复用的 Lua 模块（`return` 一个 table，用 `require("名字")` 引用）。

规则：
- 改这里之前先确认哪些项目引用了它；改动写进受影响项目的 `CHANGELOG.md`。
- 模块名与文件名一致：`lib/chat_log.lua` → `require("chat_log")`（部署到电脑时保持同样相对路径）。
- 不要依赖具体项目的外设布局；通过参数把外设对象传进来。
