--[[- 外设探测脚本 —— 每台电脑开工前先跑一次，把输出贴给 Agent

为什么需要：脚本（jar 扫描）只能看出"mod 里写了什么"，看不出"这台电脑实际连了什么、类型名是什么、
方法叫什么"。这个程序把现场情况一次性打印出来，是 Agent 判断能否开工的关键输入。

用法：
  - 一键版（电脑能上网时）：
      wget https://raw.githubusercontent.com/Mepuru/CreateCC/main/code/templates/probe_peripherals.lua /probe_peripherals.lua
      probe_peripherals
  - 手动版：edit /probe_peripherals.lua 粘贴本文件 → 运行 `probe_peripherals`
  - ⚠️ 别把代码直接粘到 shell 的 `>` 提示符里（那是命令行，不是 Lua），会报 No such program

输出内容：
  1) CC:T 与电脑基本信息
  2) CC: Sable 注入的全局 API / require 模块是否存在
  3) 每个已连接外设：挂载名、类型名、可枚举的方法列表
  4) Create 物流专项：能否找到库存查询器、它的物流网络里有多少种物品
]]

local function hr(char, n)
  return string.rep(char or "-", n or 44)
end

-- 可选参数：想在查询器的网络里查某个物品有多少，就带上物品 id：
--   probe_peripherals minecraft:infested_stone_bricks
local targetItem = ...
if type(targetItem) ~= "string" or targetItem == "" then
  targetItem = nil
end

--- 调用函数并返回结果；失败返回 nil + 错误文本
local function safeCall(fn, ...)
  local ok, a, b, c = pcall(fn, ...)
  if not ok then
    return nil, tostring(a)
  end
  return a, b, c
end

--- 把"可能返回 0 个值"的调用安全地变成字符串。
--- CC:T 的 Java 接口返回 null 时给的是 **0 个值**，直接 tostring(f()) 会抛
--- "bad argument #1 (value expected)"（例如没设标签的 os.getComputerLabel()）。
local function show(...)
  if select("#", ...) == 0 then
    return "nil"
  end
  local first = ...
  if first == nil then
    return "nil"
  end
  return tostring(first)
end

print(hr("="))
print("== CC:T environment probe ==")
print("os.version     : " .. show(safeCall(os.version)))
print("computer id    : " .. show(safeCall(os.getComputerID)))
print("computer label : " .. show(os.getComputerLabel()))
print("free space     : " .. show(safeCall(fs.getFreeSpace, "/")))

-- CC: Sable 注入的 ROM 附加（没装则为 nil / require 失败，属正常）
print(hr("-"))
print("== ROM extras (CC: Sable etc.) ==")
for _, name in ipairs({ "aero", "matrix", "quaternion", "sublevel" }) do
  local value = _G[name]
  print(("  %-11s : %s"):format(name, value ~= nil and type(value) or "missing"))
end
for _, mod in ipairs({ "advanced_math.mmath", "advanced_math.pid", "advanced_math.stats" }) do
  local ok, res = pcall(require, mod)
  print(("  require %-22s : %s"):format(mod, ok and "OK" or ("failed - " .. show(res))))
end

-- 已连接外设
print(hr("-"))
local names = peripheral.getNames()
print(("== connected peripherals (%d) =="):format(#names))
if #names == 0 then
  print("  (none - check the block is next to the computer, or the modem is attached)")
end

for _, name in ipairs(names) do
  print(hr("-"))
  print(("name: %s"):format(name))
  print(("type: %s"):format(show(safeCall(peripheral.getType, name))))

  local methods = {}
  local wrapped = peripheral.wrap(name)
  if type(wrapped) == "table" then
    for k, v in pairs(wrapped) do
      if type(v) == "function" then
        methods[#methods + 1] = tostring(k)
      end
    end
  end
  table.sort(methods)
  if #methods > 0 then
    print("methods: " .. table.concat(methods, ", "))
  else
    print("methods: (cannot enumerate via pairs; native peripheral - see the mod docs)")
  end
end

-- Create 物流专项：库存查询器 + 它的网络里有多少种物品
print(hr("-"))
print("== Create logistics check ==")
local ticker = peripheral.find("Create_StockTicker")
if not ticker then
  print("Create_StockTicker: NOT FOUND")
  print("  -> put it next to the computer (any side), or on the same wired modem network")
  print("  -> wireless (ender) modems cannot expose remote peripherals")
else
  local okStock, stock = pcall(ticker.stock)
  if not okStock then
    print("Create_StockTicker: found, but stock() failed - " .. show(stock))
  else
    local entries = 0
    for _ in pairs(stock or {}) do
      entries = entries + 1
    end
    print(("Create_StockTicker: found, network entries = %d"):format(entries))

    -- 列出网络内容（最多 15 条），用来判断"这条网络到底有没有我要的东西"
    local shown = 0
    for _, entry in pairs(stock or {}) do
      if shown >= 15 then
        print("  ... (truncated)")
        break
      end
      shown = shown + 1
      print(("  %-44s %s"):format(tostring(entry.name), show(entry.count)))
    end

    if entries == 0 then
      print("  -> network is EMPTY: tune a Stock Link item on the warehouse Stock Link,")
      print("     then right-click the ticker (or place the ticker with the tuned item)")
      print("  -> also make sure the warehouse chunks are loaded")
    end

    -- 可选：查某个物品在这条网络里有多少（用法：probe_peripherals minecraft:infested_stone_bricks）
    if targetItem then
      local count = nil
      for _, entry in pairs(stock or {}) do
        if entry.name == targetItem then
          count = tonumber(entry.count) or -1
          break
        end
      end
      print(("target %s : %s"):format(targetItem, count and tostring(count) or "NOT IN THIS NETWORK"))
    end
  end
end
if peripheral.find("Create_RedstoneRequester") then
  print("Create_RedstoneRequester: found")
else
  print("Create_RedstoneRequester: not found (optional - used for ordering)")
end

print(hr("="))
print("probe done - copy this whole output back to the agent.")
