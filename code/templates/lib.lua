--[[- <库名> — <一句话说明>

用法（部署时保持相对路径一致，例如两者都在 /create_cc/ 下）：
  local mylib = require("mylib")
  mylib.doThing()

注意：
  - require 走 package.path，不是文件路径；子目录用 require("a.b") 对应 a/b.lua
  - 详见 docs/cc-tweaked/doc/guides/using_require.md
]]

local M = {}

-- TODO(D): 在这里实现函数，全部用 local 定义后挂到 M 上，避免污染全局

--- 示例：把文本居中写到屏幕上
function M.writeCenter(target, text)
  local w = target.getSize()
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  target.setCursorPos(x, 1)
  target.write(text)
end

return M
