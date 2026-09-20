--[[- stock_controller 一键更新器

在电脑上运行：
    update_stock            :: 下载 main.lua + config.lua 到 /stock_controller/ 并打印版本号
    update_stock --keep     :: 只更新 main.lua（保留你手改过的 config.lua）

它做三件事：
  1) 从 GitHub raw 下载文件（需要电脑能上网；CC:T 默认允许公网域名）
  2) 写进 /stock_controller/，并**读回文件里的 VERSION 行**确认真的换成了新版
  3) 提示你 Ctrl+T 退出并重新启动程序

⚠️ 重要：CC:T 是把程序读进内存运行的——**光替换文件不生效，必须重启程序**。

部署（第一次用它的方式有点绕：得先把它下下来）：
    mkdir /stock_controller
    wget https://raw.githubusercontent.com/Mepuru/CreateCC/main/code/stock_controller/update.lua /stock_controller/update.lua
    stock_controller/update
之后就可以一直用 `stock_controller/update` 更新了。
]]

local BASE = "https://raw.githubusercontent.com/Mepuru/CreateCC/main/code/stock_controller/"
local DIR = "/stock_controller"
local ALL = { "main.lua", "config.lua" }

local function usage()
  print("usage: update_stock [--keep]")
  print("  --keep : only update main.lua (keep your edited config.lua)")
end

local keepConfig = false
for _, arg in ipairs({ ... }) do
  if arg == "--keep" then
    keepConfig = true
  elseif arg == "-h" or arg == "--help" then
    usage()
    return
  end
end

if not fs.exists(DIR) then
  fs.makeDir(DIR)
end

local function download(name)
  local url = BASE .. name
  write(("downloading %-12s ... "):format(name))
  local response, err = http.get(url)
  if not response then
    print("FAILED: " .. tostring(err))
    return false
  end
  local body = response.readAll()
  response.close()
  if type(body) ~= "string" or #body == 0 then
    print("FAILED: empty body")
    return false
  end
  local handle = fs.open(fs.combine(DIR, name), "w")
  if not handle then
    print("FAILED: cannot write " .. name)
    return false
  end
  handle.write(body)
  handle.close()
  print(("ok (%d bytes)"):format(#body))
  return true
end

local files = { "main.lua" }
if not keepConfig then
  table.insert(files, "config.lua")
else
  print("(--keep: config.lua left untouched)")
end

local failed = false
for _, name in ipairs(files) do
  if not download(name) then
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
  print("Some steps failed - check the messages above and your internet access.")
else
  print("Done. Now RESTART the program so it reloads the new code:")
  print("  1) press Ctrl+T to stop the running program")
  print("  2) run:  stock_controller/main")
end
