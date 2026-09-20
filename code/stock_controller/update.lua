--[[- stock_controller 一键更新器（默认走 gh-proxy 加速，失败自动回退到直连）

在电脑上运行：
    stock_controller/update                :: 更新 main.lua + config.lua
    stock_controller/update --keep          :: 只更新 main.lua（保留你手改过的 config.lua）
    stock_controller/update --direct        :: 跳过 gh-proxy，直连 raw.githubusercontent.com

为什么默认走代理：国内网络经常连不上 raw.githubusercontent.com；gh-proxy 是公开的 GitHub 转发服务
（本项目克隆上游资料也用同一个前缀）。下载顺序是 **gh-proxy → 直连**，谁先成功用谁，并会在日志里说明。

它做三件事：
  1) 下载文件（会打印用的是哪条线路）
  2) 写进 /stock_controller/，并**读回文件里的 VERSION 行**确认真的换了新版
  3) 提示你 Ctrl+T 退出并重新启动程序

⚠️ CC:T 是把程序读进内存运行的——**光替换文件不生效，必须重启程序**。
]]

local DIR = "/stock_controller"
local PATH_IN_REPO = "code/stock_controller/"
local RAW_HOST = "https://raw.githubusercontent.com/Mepuru/CreateCC/main/" .. PATH_IN_REPO
local FILENAME = { "main.lua", "config.lua" }

-- 可选参数
local keepConfig, directOnly = false, false
for _, arg in ipairs({ ... }) do
  if arg == "--keep" then
    keepConfig = true
  elseif arg == "--direct" then
    directOnly = true
  elseif arg == "-h" or arg == "--help" then
    print("usage: update_stock [--keep] [--direct]")
    print("  --keep   : only update main.lua (keep your edited config.lua)")
    print("  --direct : skip gh-proxy, download straight from raw.githubusercontent.com")
    return
  end
end

local sources = {}
if not directOnly then
  table.insert(sources, { name = "gh-proxy", base = "https://v6.gh-proxy.org/" .. RAW_HOST })
end
table.insert(sources, { name = "direct  ", base = RAW_HOST })

if not fs.exists(DIR) then
  fs.makeDir(DIR)
end

local function fetch(base, name)
  local response, err = http.get(base .. name)
  if not response then
    return nil, tostring(err)
  end
  local body = response.readAll()
  response.close()
  if type(body) ~= "string" or #body == 0 then
    return nil, "empty body"
  end
  return body
end

local files = { "main.lua" }
if keepConfig then
  print("(--keep: config.lua left untouched)")
else
  table.insert(files, "config.lua")
end

local failed = false
for _, name in ipairs(files) do
  local saved = false
  for _, src in ipairs(sources) do
    write(("downloading %-11s via %s ... "):format(name, src.name))
    local body, err = fetch(src.base, name)
    if body then
      local handle = fs.open(fs.combine(DIR, name), "w")
      if not handle then
        print("FAILED: cannot write " .. name)
      else
        handle.write(body)
        handle.close()
        print(("ok (%d bytes)"):format(#body))
        saved = true
      end
      break
    end
    print("FAILED: " .. tostring(err))
  end
  if not saved then
    print("  -> all sources failed for " .. name)
    failed = true
  end
end

-- 读回文件，确认版本真的换了（这是"我以为更新了"的克星）
local handle = fs.open(fs.combine(DIR, "main.lua"), "r")
if handle then
  local src = handle.readAll()
  handle.close()
  local version = src:match('VERSION = "([^"]+)"')
  if version then
    print(("installed main.lua version: %s"):format(version))
  else
    print("!! main.lua has NO VERSION line - it is an OLD build (download failed?)")
    failed = true
  end
else
  print("!! cannot read back " .. DIR .. "/main.lua")
  failed = true
end

print("")
if failed then
  print("Some steps failed - check the messages above, or try: update --direct")
else
  print("Done. Now RESTART the program so it reloads the new code:")
  print("  1) press Ctrl+T to stop the running program")
  print("  2) run:  stock_controller/main")
end
