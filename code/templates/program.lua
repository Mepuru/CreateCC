--[[- <程序名> — <一句话说明这个程序干什么>

依赖：
  - Minecraft 1.21.1 / NeoForge / Create 6.0.x / CC: Tweaked 1.119+
  - （可选）CC:C Bridge 1.7.3
需要的外设（类型名必须与 docs/API_*.md 一致，区分大小写）：
  - Create_Station      （列车站；与电脑相邻或经 modem 接入）
  - （按需增删）
监听的事件：
  - train_arrival(side, stationName, trainName)   ← 第 1 个参数是外设名
用法：
  - 部署路径：/<path>/main.lua
  - 运行：在电脑 shell 里输入 `main`
API 出处（改代码前请核对这几处）：
  - docs/create-wiki/src/users/cc-tweaked-integration/train/train-station.md
  - docs/create-source/src/main/java/com/simibubi/create/compat/computercraft/implementation/peripherals/StationPeripheral.java
  - docs/create-source/src/main/java/com/simibubi/create/compat/computercraft/implementation/peripherals/SyncedPeripheral.java  （事件参数前缀）
]]

local LOG_PREFIX = "[main] "

local function log(fmt, ...)
  print(LOG_PREFIX .. string.format(fmt, ...))
end

--- 调用外设方法并兜住异常。返回第一个返回值；失败返回 nil。
-- @param label  用于报错的说明，例如 "Create_Station.getStationName"
-- @param fn     方法（传 `station.getStationName`，不要加括号）
local function safeCall(label, fn, ...)
  local ok, a, b, c = pcall(fn, ...)
  if not ok then
    log("call failed %s: %s", label, tostring(a))
    return nil
  end
  return a, b, c
end

--- 依次尝试若干外设类型名，返回 name, wrapped, type
local function findAny(...)
  for _, t in ipairs({ ... }) do
    local name, p = peripheral.find(t) -- 注意：find 返回 (name, wrapped)
    if p then return name, p, t end
  end
  return nil
end

--- 外设找不到时，打印现场信息，方便用户回报
local function dumpPeripherals()
  log("connected peripherals:")
  local names = peripheral.getNames()
  if #names == 0 then
    log("  (none - check the block is next to the computer, or the modem is attached)")
  end
  for _, n in ipairs(names) do
    print("  ", n, peripheral.getType(n))
  end
end

local function main()
  local stationName, station = findAny("Create_Station")
  if not station then
    log("Create_Station peripheral not found - put the train station next to the computer, or attach it via a modem.")
    dumpPeripherals()
    return false
  end

  log("peripheral: %s (%s)", stationName, peripheral.getType(stationName))
  log("station: %s", tostring(safeCall("Create_Station.getStationName", station.getStationName)))

  -- TODO(D): 启动后的初始化（设置站名、显示初始界面等）

  while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "terminate" then
      log("terminate received; restoring state and exiting")
      -- TODO(D): 这里把外设恢复到安全状态（解锁 / 关红石 / 清屏）
      break
    elseif event == "peripheral" or event == "peripheral_detach" then
      log("peripheral change: %s %s (re-find peripherals if needed)", event, tostring(p1))
    elseif event == "train_arrival" then
      -- p1 = 外设名, p2 = 站名, p3 = 列车名（见本文件头部 API 出处）
      log("train arrival: station=%s train=%s", tostring(p2), tostring(p3))
      -- TODO(D): 到站逻辑
    elseif event == "train_departure" then
      log("train departure: station=%s train=%s", tostring(p2), tostring(p3))
    elseif event == "timer" then
      -- TODO(D): 定时逻辑（配合 os.startTimer 使用）
    end
  end

  return true
end

local ok, err = pcall(main)
if not ok then
  log("crash: %s", tostring(err))
end
