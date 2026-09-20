--[[- 外设探测脚本 —— 每台电脑开工前先跑一次，把输出贴给 Agent

为什么需要：脚本（jar 扫描）只能看出"mod 里写了什么"，看不出"这台电脑实际连了什么、类型名是什么、
方法叫什么"。这个程序把现场情况一次性打印出来，是 Agent 判断能否开工的关键输入。

用法：
  - 部署路径建议：/probe_peripherals.lua（单文件，无依赖）
  - 运行：在电脑 shell 里输入 `probe_peripherals`
  - 把完整输出复制给 Agent

覆盖内容：
  1) CC:T 与电脑基本信息
  2) CC: Sable 注入的全局 API / require 模块是否存在
  3) 每个已连接外设：挂载名、类型名、可枚举的方法列表
]]

local function hr(char, n)
  return string.rep(char or "-", n or 44)
end

local function safe(label, fn, ...)
  local ok, a, b, c = pcall(fn, ...)
  if not ok then
    return nil, tostring(a)
  end
  return a, b, c
end

print(hr("="))
print("== CC:T 环境探测 ==")
print("os.version     : " .. tostring(safe(os.version)))
print("电脑 id / label: " .. tostring(os.getComputerID()) .. " / " .. tostring(os.getComputerLabel()))
print("free space     : " .. tostring(safe(fs.getFreeSpace, "/")))

-- CC: Sable 注入的 ROM 附加（没装则为 nil / require 失败，属正常）
print(hr("-"))
print("== ROM 附加（CC: Sable 等） ==")
for _, name in ipairs({ "aero", "matrix", "quaternion", "sublevel" }) do
  local value = _G[name]
  print(("  %-11s : %s"):format(name, value ~= nil and type(value) or "不存在"))
end
for _, mod in ipairs({ "advanced_math.mmath", "advanced_math.pid", "advanced_math.stats" }) do
  local ok, res = pcall(require, mod)
  print(("  require %-22s : %s"):format(mod, ok and "OK" or ("失败 - " .. tostring(res))))
end

-- 已连接外设
print(hr("-"))
local names = peripheral.getNames()
print(("== 已连接外设（%d 个） =="):format(#names))
if #names == 0 then
  print("  （一个都没有：检查方块是否贴着电脑，或 modem 是否接好）")
end

for _, name in ipairs(names) do
  local ptype = safe(peripheral.getType, name)
  print(hr("-"))
  print(("挂载名: %s"):format(name))
  print(("类型名: %s"):format(tostring(ptype)))

  local methods = {}
  local p = peripheral.wrap(name)
  if type(p) == "table" then
    for k, v in pairs(p) do
      if type(v) == "function" then
        methods[#methods + 1] = tostring(k)
      end
    end
  end
  table.sort(methods)
  if #methods > 0 then
    print("方法  : " .. table.concat(methods, ", "))
  else
    print("方法  : （无法用 pairs 枚举，可能是 native 外设；请查该 mod 的文档）")
  end
end

print(hr("="))
print("探测完成，请把以上完整输出复制给 Agent。")
