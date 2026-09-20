--[[- 仓库控制器 —— 用 CC 电脑替代工厂仪表，带显示屏

干什么：
  轮询仓库网络的库存 → 按 config.rules 逐条判断 → 不足就下单补货 → 输出红石 + 刷新显示屏。
  一块工厂仪表只能盯 1 种物品；这个程序能同时盯 N 种，支持每物品独立阈值、滞回、冷却、在途记账。

依赖（全部 Create 原生 / CC:T 自带，**不需要额外 mod**）：
  - Minecraft 1.21.1 / NeoForge / Create 6.0.10 / CC: Tweaked 1.120.2（本实例实测版本）
  - 必须：Create 库存查询器（Create_StockTicker），并且要"加入仓库的物流网络"：
    用打包机链接（Stock Link）物品右键仓库的 Stock Link 调谐，再右键查询器（或用调谐好的物品放置）。
    注意：不是用「频率（Frequency）」物品，那是红石链接系统的
  - 可选：Create 红石请求器（Create_RedstoneRequester）→ 支持 setCraftingRequest 自动合成
  - 可选：显示屏 —— Create 显示链接（Create_DisplayLink）或 CC:T 显示器（monitor）；都没有就用电脑自身屏幕
  - 可选：redstone_relay（CC:T 自带）→ 需要多路/远距离红石；否则用电脑自带 redstone API
  - 可选：蛙港/邮筒（Create_Frogport / Create_Postbox）→ 用 package_sent/package_received 事件核销"在途"

部署：
  /stock_controller/config.lua      ← 先改这个（物品、阈值、地址）
  /stock_controller/main.lua
  运行：在电脑 shell 输入 `stock_controller/main`（或把 main.lua 放到 /stock_controller 后 cd 进去运行）

API 出处（改代码前先核对）：
  - compat/computercraft/implementation/peripherals/StockTickerPeripheral.java   （stock / requestFiltered）
  - compat/computercraft/implementation/peripherals/RedstoneRequesterPeripheral.java（setRequest/setCraftingRequest/request）
  - compat/computercraft/implementation/peripherals/DisplayLinkPeripheral.java   （clear/setCursorPos/write/getSize/update）
  - content/logistics/packagerLink/LogisticsManager.java                         （网络汇总与缓存语义）
  - docs/API_CREATE_NATIVE.md 末尾「用 CC 替代工厂仪表」章节
]]

local LOG = "[stock] "

-- 版本号：屏幕上会显示短版本（v0.7），启动日志会打印完整版本。
-- 排查"改了文件却没生效"时先看这里——CC:T 把程序读进内存，替换文件后必须重启程序。
local VERSION = "0.7.0"
local SHORT_VERSION = VERSION:match("^%d+%.%d+") or VERSION

local function log(fmt, ...)
  print(LOG .. string.format(fmt, ...))
end

-- 配置 ---------------------------------------------------------------------
local okConfig, config = pcall(require, "config")
if not okConfig then
  log("cannot load config.lua (must sit next to main.lua): " .. tostring(config))
  return
end
config.rules = config.rules or {}
if #config.rules == 0 then
  log("config.rules is empty - add the items to watch in config.lua")
  return
end

local POLL = config.pollInterval or 2

-- 运行状态 -----------------------------------------------------------------
local state = {
  inventory = {},   -- itemName -> 网络在库数量
  ledger = {},      -- itemName -> 已下单但尚未到货的数量（在途）
  ledgerAt = {},    -- itemName -> 在途账本最后一次变动的时间（用于超时清零）
  lowOverride = {}, -- itemName -> 显示器按钮调过的 low 覆盖值（会存进状态文件）
  auto = true,      -- 自动补货开关（显示器 [AUTO] 按钮可切）
  elapsed = 0,      -- 程序启动后的秒数（用作冷却计时，避免依赖 os.clock 的 CPU 语义）
  lastOrder = {},   -- itemName -> 上次下单时的 elapsed
  lastPoll = 0,
  networkOk = false,
  lastError = nil,
  notice = nil,
  buttons = {},     -- 本帧的按钮区域（渲染时重建，触摸时命中测试）
  touchMsg = nil,   -- 触摸反馈（下次渲染显示一行）
  lastTouch = 0,    -- 上次触摸的毫秒时间戳（防连点）
}

-- 外设句柄（rebind 时更新）
local display, displayKind = term, "term"
local ticker, requester
local relays = {}   -- name -> wrapped redstone_relay

-- 状态持久化 ---------------------------------------------------------------
local function saveState()
  local path = config.stateFile or "/stock_controller/state.tbl"
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    pcall(fs.makeDir, dir)
  end
  local handle = fs.open(path, "w")
  if not handle then
    return false
  end
  handle.write(textutils.serialize({
    ledger = state.ledger,
    lowOverride = state.lowOverride,
    auto = state.auto,
  }))
  handle.close()
  return true
end

local function loadState()
  local path = config.stateFile or "/stock_controller/state.tbl"
  if not fs.exists(path) then
    return
  end
  local handle = fs.open(path, "r")
  if not handle then
    return
  end
  local raw = handle.readAll()
  handle.close()
  local ok, parsed = pcall(textutils.unserialize, raw)
  if ok and type(parsed) == "table" then
    if type(parsed.ledger) == "table" then
      state.ledger = parsed.ledger
      local count = 0
      for _ in pairs(state.ledger) do
        count = count + 1
      end
      if count > 0 then
        log(("restored %d inflight entries"):format(count))
      end
    end
    if type(parsed.lowOverride) == "table" then
      state.lowOverride = parsed.lowOverride
      local count = 0
      for _ in pairs(state.lowOverride) do
        count = count + 1
      end
      if count > 0 then
        log(("restored %d threshold override(s) from the monitor buttons"):format(count))
      end
    end
    if parsed.auto ~= nil then
      state.auto = parsed.auto and true or false
      if not state.auto then
        log("auto restock is OFF (was turned off from the monitor)")
      end
    end
  end
end

--- 启动时把显示器上调过的阈值覆盖值套用到 rules 上（high 跟着平移，保持滞回宽度）
local function applyOverrides()
  for _, rule in ipairs(config.rules) do
    local override = state.lowOverride[rule.item]
    if type(override) == "number" and override >= 0 then
      local span = (rule.high or rule.low) - rule.low
      rule.low = math.floor(override)
      rule.high = rule.low + span
    end
  end
end

-- 外设绑定 -----------------------------------------------------------------
-- ⚠️ peripheral.find(type) 返回的是**已包装外设表**（0 个或多个），**不返回 name**！
--    出处：CC:T ROM 的 rom/apis/peripheral.lua `find()` —— 只 `table.insert(results, wrapped)`。
--    （老 CC1 文档里的 "(name, wrapped)" 是过时语义，照抄会拿到 nil。）
--    需要名字时用 peripheral.getName(wrapped)。
local function nameOf(wrapped)
  if not wrapped then
    return "none"
  end
  local ok, name = pcall(peripheral.getName, wrapped)
  if ok and type(name) == "string" then
    return name
  end
  return "?"
end

local function findDisplay()
  local wanted = (config.display or {}).kind or "auto"
  if wanted == "auto" or wanted == "display_link" then
    local wrapped = peripheral.find("Create_DisplayLink")
    if wrapped then
      return wrapped, "display_link", nameOf(wrapped)
    end
    if wanted == "display_link" then
      return term, "term", "term"
    end
  end
  if wanted == "auto" or wanted == "monitor" then
    local wrapped = peripheral.find("monitor")
    if wrapped then
      return wrapped, "monitor", nameOf(wrapped)
    end
  end
  return term, "term", "term"
end

local function rebind()
  display, displayKind, state.displayName = findDisplay()

  ticker = peripheral.find("Create_StockTicker")
  state.tickerName = nameOf(ticker)
  if not ticker then
    state.lastError = "Create_StockTicker peripheral not found"
  end

  requester = peripheral.find("Create_RedstoneRequester")

  relays = {}
  for _, name in ipairs(peripheral.getNames()) do
    local okType, ptype = pcall(peripheral.getType, name)
    if okType and ptype == "redstone_relay" then
      relays[name] = peripheral.wrap(name)
    end
  end
end

-- 读取库存 -----------------------------------------------------------------
local function refreshInventory()
  if not ticker then
    rebind()
  end
  if not ticker then
    log("no Create_StockTicker peripheral - put it next to the computer (or on the wired network)")
    error("NO TICKER")
  end

  -- stock(detailed?) 返回 { [1] = {name=, displayName=, count=}, ... }（1 基）
  local stock = ticker.stock()
  if type(stock) ~= "table" then
    log("stock() returned no table - ticker not on the network, or its frequency differs from the warehouse")
    error("NO DATA (freq?)")
  end
  local inventory = {}
  local entries = 0
  for _, entry in pairs(stock) do
    entries = entries + 1
    local itemName = entry.name
    if type(itemName) == "string" then
      inventory[itemName] = (inventory[itemName] or 0) + (tonumber(entry.count) or 0)
    end
  end

  -- 空网络 ≠ 库存为 0：多半是查询器没接入仓库网络，或仓库区块没加载。
  -- 这时绝对不能当成"库存 0"去下单（会每 30 秒刷一次单），所以按"读不到"处理。
  if entries == 0 and (config.emptyMeansUnknown ~= false) then
    log("stock() returned an EMPTY network - the ticker is not on the warehouse network "
      .. "(tune a Stock Link item on the warehouse Stock Link, then right-click the ticker), "
      .. "or the warehouse chunks are not loaded")
    error("EMPTY NETWORK (freq?)")
  end

  state.inventory = inventory
  state.lastPoll = state.elapsed
  state.networkOk = true
  state.lastError = nil
end

-- 下单 ---------------------------------------------------------------------
local function orderViaRequester(rule)
  if not requester then
    return nil, "no redstone requester"
  end
  local ok, err = pcall(function()
    -- ⚠️ 地址只能用 ASCII：CC:T 把 Lua 字符串按字节交给 Java，
    --    中文字符串会失真（实测：请求器的地址栏变成乱码，包裹就送不到目的地）。
    --    所以默认不写地址（setAddressOnOrder = false），请在请求器 GUI 里直接填地址；
    --    想用程序写地址，就把 frogport 地址改成 ASCII（例如 exp）并设 setAddressOnOrder = true。
    if config.setAddressOnOrder ~= false and rule.address then
      requester.setAddress(rule.address)
    end
    requester.setConfiguration(rule.configuration or "allow_partial")
    if rule.craft then
      -- setCraftingRequest(批次数, 物品...)：第一个参数是批数，之后最多 9 个物品 id
      requester.setCraftingRequest(rule.batches or 1, rule.item)
    else
      -- setRequest(物品...)：最多 9 槽，每槽 count ≤ 256；需要更多就把同一物品铺到多个槽
      local remaining = rule.batch or (rule.high - rule.low)
      local slots = {}
      while remaining > 0 and #slots < 9 do
        local per = math.min(remaining, 256)
        slots[#slots + 1] = { name = rule.item, count = per }
        remaining = remaining - per
      end
      if remaining > 0 then
        log("requester has 9 slots max: %s still has %d unqueued, lower batch", rule.item, remaining)
      end
      requester.setRequest(table.unpack(slots))
    end
    requester.request()
  end)
  if not ok then
    return nil, tostring(err)
  end
  -- 请求器不返回实际发出数量，这里按批量记账（可能少于批量，靠 package 事件核销）
  return rule.batch or (rule.high - rule.low)
end

local function orderViaTicker(rule)
  if not ticker then
    return nil, "no stock ticker"
  end
  local filter = { name = rule.item, _requestCount = rule.batch or (rule.high - rule.low) }
  local ok, sent = pcall(ticker.requestFiltered, rule.address or "", filter)
  if not ok then
    return nil, tostring(sent)
  end
  return tonumber(sent) or 0
end

local function placeOrder(rule)
  local amount, err
  local via = config.orderVia or "auto"

  if via == "requester" or (via == "auto" and requester) then
    amount, err = orderViaRequester(rule)
  else
    amount, err = orderViaTicker(rule)
  end

  if err then
    state.lastError = ("order failed %s: %s"):format(rule.item, err)
    log(state.lastError)
    return
  end

  state.ledger[rule.item] = (state.ledger[rule.item] or 0) + (amount or 0)
  state.ledgerAt[rule.item] = state.elapsed
  state.lastOrder[rule.item] = state.elapsed
  state.notice = ("%s +%d"):format(rule.label or rule.item, amount or 0)
  log(("ordered %s x%d (inflight total %d)"):format(rule.item, amount or 0, state.ledger[rule.item]))
  saveState()
end

local function decide()
  if state.auto == false then
    return   -- 显示器上把自动补货关掉了（[AUTO] 按钮）
  end
  for _, rule in ipairs(config.rules) do
    local have = state.inventory[rule.item] or 0
    local inflight = state.ledger[rule.item] or 0
    local projected = have + inflight
    local cooldown = rule.cooldown or config.cooldown or 30
    local last = state.lastOrder[rule.item]

    -- 在途超时：下了单却一直没到货（例如地址送去了别处、或该物品根本不在网上），
    -- 账本会永远挂着让程序不再下单。开启 inflightTimeout 后到点清零并告警。
    local timeout = rule.inflightTimeout or config.inflightTimeout or 0
    if timeout > 0 and inflight > 0 then
      local since = state.ledgerAt[rule.item] or state.elapsed
      if (state.elapsed - since) >= timeout then
        log(("inflight for %s timed out after %ds (still 0 in stock?): ledger reset to 0 - "
          .. "check the order address and whether the items land on THIS network")
          :format(rule.item, timeout))
        state.ledger[rule.item] = 0
        inflight = 0
        projected = have
        saveState()
      end
    end

    if projected >= (rule.high or rule.low) then
      -- 补货到位，清掉在途账本
      if inflight ~= 0 then
        state.ledger[rule.item] = 0
        saveState()
      end
    elseif projected < rule.low then
      if last == nil or (state.elapsed - last) >= cooldown then
        placeOrder(rule)
      end
    end
  end
end

-- 红石输出 -----------------------------------------------------------------
local function applySignals()
  for _, rule in ipairs(config.rules) do
    local signal = rule.signal
    if signal then
      local have = (state.inventory[rule.item] or 0) + (state.ledger[rule.item] or 0)
      local satisfied = have >= (rule.low or 0)
      local level = satisfied and (signal.okLevel or 0) or (signal.lowLevel or 15)

      -- 没指定 peripheral 就用电脑自带的 redstone API，两者方法名一致
      local target = redstone
      if signal.peripheral then
        target = relays[signal.peripheral]
      end
      if target then
        local ok, err = pcall(target.setAnalogOutput, signal.side or "left", level)
        if not ok then
          state.lastError = ("redstone output failed %s: %s"):format(rule.label or rule.item, tostring(err))
        end
      end
    end
  end
end

-- 退出时的红石处理：默认保持现状（"hold"），也可设成 "clear" 全部归零
local function shutdownSignals()
  if (config.signalOnExit or "hold") ~= "clear" then
    return
  end
  for _, rule in ipairs(config.rules) do
    local signal = rule.signal
    if signal then
      local target = redstone
      if signal.peripheral then
        target = relays[signal.peripheral]
      end
      if target then
        pcall(target.setAnalogOutput, signal.side or "left", 0)
      end
    end
  end
end

-- 在途核销（蛙港/邮筒事件） ------------------------------------------------
local function reconcilePackage(package)
  if not config.reconcilePackages or type(package) ~= "table" then
    return
  end
  local ok, items = pcall(package.list)
  if not ok or type(items) ~= "table" then
    return
  end
  local changed = false
  for _, entry in pairs(items) do
    local name, count = entry.name, tonumber(entry.count) or 0
    if name and state.ledger[name] and state.ledger[name] > 0 then
      state.ledger[name] = math.max(0, state.ledger[name] - count)
      changed = true
    end
  end
  if changed then
    saveState()
  end
end

-- 显示器按钮（高级显示器，触摸触发 monitor_touch 事件） ---------------------
-- 布局：屏幕最后一行放 [ORDER] [AUTO] [LOW-] [LOW+]；倒数第二行显示提示/反馈。
-- 出处：https://tweaked.cc/event/monitor_touch.html（事件参数：外设名, x, y）
local TOUCH_COOLDOWN_MS = 800
local LOW_STEP = config.buttonLowStep or 1024
local MANUAL_ORDER_COOLDOWN = 3   -- 秒：手动下单防连点

local function touchNow()
  local ok, ms = pcall(os.epoch, "utc")
  if ok and type(ms) == "number" then
    return ms
  end
  return state.elapsed * 1000
end

--- 手动下单一次（带防连点）
local function manualOrder(rule)
  local last = state.lastOrder[rule.item]
  if last and (state.elapsed - last) < MANUAL_ORDER_COOLDOWN then
    state.touchMsg = "please wait a few seconds"
    return
  end
  placeOrder(rule)
  state.touchMsg = ("manual order: %s"):format(rule.label or rule.item)
end

local function toggleAuto()
  state.auto = not state.auto
  state.touchMsg = state.auto and "auto restock: ON" or "auto restock: OFF"
  log("auto restock is now " .. (state.auto and "ON" or "OFF"))
  saveState()
end

--- 现场调阈值：low ± LOW_STEP，high 跟着平移（保持滞回宽度），并存进状态文件
local function bumpLow(rule, delta)
  local span = rule.high - rule.low
  local low = math.max(0, rule.low + delta)
  rule.low = low
  rule.high = low + span
  state.lowOverride[rule.item] = low
  state.touchMsg = ("target: low %d / high %d"):format(rule.low, rule.high)
  log(("threshold from monitor: %s low=%d high=%d"):format(rule.item, rule.low, rule.high))
  saveState()
end

local function handleButton(id)
  local rule = config.rules[1]
  if not rule then
    return
  end
  if id == "order" then
    manualOrder(rule)
  elseif id == "auto" then
    toggleAuto()
  elseif id == "low-" then
    bumpLow(rule, -LOW_STEP)
  elseif id == "low+" then
    bumpLow(rule, LOW_STEP)
  end
end

--- 触摸命中测试（x/y 为显示器字符坐标）
local function handleTouch(x, y)
  local now = touchNow()
  if now - state.lastTouch < TOUCH_COOLDOWN_MS then
    return
  end
  state.lastTouch = now
  for _, btn in ipairs(state.buttons) do
    if btn.y == y and x >= btn.x and x < (btn.x + #btn.label) then
      handleButton(btn.id)
      return
    end
  end
end

--- 计算本帧按钮区域（渲染时调用）
local function buildButtons(y, width)
  local full = {
    { id = "order", label = "[ORDER]" },
    { id = "auto", label = "[AUTO]" },
    { id = "low-", label = "[LOW-]" },
    { id = "low+", label = "[LOW+]" },
  }
  local short = {
    { id = "order", label = "[ORD]" },
    { id = "auto", label = "[AUT]" },
    { id = "low-", label = "[L-]" },
    { id = "low+", label = "[L+]" },
  }
  local function total(list)
    local n = 0
    for _, b in ipairs(list) do
      n = n + #b.label + 1
    end
    return n
  end

  local buttons = (total(full) <= width) and full or short
  local x = 1
  for _, btn in ipairs(buttons) do
    btn.x = x
    btn.y = y
    if btn.id == "order" then
      btn.bg, btn.fg = colors.green, colors.black
    elseif btn.id == "auto" then
      btn.bg, btn.fg = state.auto and colors.lime or colors.red, colors.black
    else
      btn.bg, btn.fg = colors.grey, colors.white
    end
    x = x + #btn.label + 1
  end
  return buttons
end

-- 显示 ---------------------------------------------------------------------
local function shortLabel(rule)
  local label = rule.label or rule.item
  return label
end

local function fit(text, width)
  if #text > width then
    return text:sub(1, width)
  end
  return text
end

-- 去掉 Lua 自动加的 "路径:行号: " 前缀，屏幕上只留可读的部分
local function shortError(text)
  return (tostring(text or "?"):gsub("^.-%.lua:%d+:%s*", ""))
end

local function render()
  local ok, width, height = pcall(display.getSize)
  if not ok or type(width) ~= "number" then
    display, displayKind = term, "term"
    width = select(1, term.getSize())
    height = select(2, term.getSize())
  end
  if type(height) ~= "number" then
    height = 20
  end
  local limit = math.min(width, (config.display or {}).widthLimit or width)
  local wide = limit >= 30          -- 窄屏（比如 1x1/2x2 显示器）用紧凑排版
  local canColor = (config.display or {}).color and display.setTextColour ~= nil
  -- 按钮只在真正的 CC 显示器上画（高级显示器才会上报 monitor_touch）。
  -- 预留行数：够高就留 2 行（提示 + 按钮），矮显示器只留 1 行给按钮。
  local showButtons = (displayKind == "monitor") and display.setBackgroundColour ~= nil and height >= 5
  local buttonReserve = 0
  if showButtons then
    buttonReserve = (height >= 8) and 2 or 1
  end

  -- 注意：这里不能把局部变量起名 colors，那会遮蔽 CC:T 的全局 colors API
  local lines, lineColors = {}, {}
  local inFlightTotal = 0
  for _, rule in ipairs(config.rules) do
    inFlightTotal = inFlightTotal + (state.ledger[rule.item] or 0)
  end

  local header = (config.display or {}).title or "STOCK CONTROL"
  if limit >= (#header + 6) then
    header = header .. "  v" .. SHORT_VERSION
  end
  lines[#lines + 1] = header
  lineColors[#lineColors + 1] = colors.white

  local status
  if not state.networkOk then
    status = "NET: " .. shortError(state.lastError or "no data")
  elseif wide then
    status = ("upd %ds ago  inflight %d%s"):format(
      state.elapsed - state.lastPoll, inFlightTotal, state.auto and "" or "  AUTO OFF")
  else
    status = ("upd %ds  inf %d%s"):format(
      state.elapsed - state.lastPoll, inFlightTotal, state.auto and "" or "  AUTO OFF")
  end
  lines[#lines + 1] = fit(status, limit)
  lineColors[#lineColors + 1] = colors.lightGrey
  -- 矮显示器没有单独一行显示触摸反馈时，把它并到状态行里
  if state.touchMsg and buttonReserve < 2 then
    lines[#lines + 1] = fit(state.touchMsg, limit)
    lineColors[#lineColors + 1] = colors.orange
  end
  lines[#lines + 1] = string.rep("-", math.min(limit, 24))
  lineColors[#lineColors + 1] = colors.grey

  for _, rule in ipairs(config.rules) do
    local have = state.inventory[rule.item] or 0
    local inflight = state.ledger[rule.item] or 0
    local projected = have + inflight
    local mark, color, haveStr
    if not state.networkOk then
      -- 没读到网络数据时显示 ? —— 别把"未知"画成 0，否则看起来像库存真空了
      mark, color, haveStr = "?", colors.grey, "?"
    elseif projected >= (rule.high or rule.low) then
      mark, color, haveStr = "OK", colors.lime, tostring(have)
    elseif projected >= rule.low then
      mark, color, haveStr = "..", colors.yellow, tostring(have)
    else
      mark, color, haveStr = "LOW", colors.red, tostring(have)
    end
    local text
    if wide then
      text = ("%-18s %5s/%-5d %-3s"):format(shortLabel(rule), haveStr, rule.low, mark)
    else
      text = ("%-10s %4s/%-4d %s"):format(shortLabel(rule):sub(1, 10), haveStr, rule.low, mark)
    end
    if inflight > 0 then
      text = text .. (" +%d"):format(inflight)
    end
    lines[#lines + 1] = fit(text, limit)
    lineColors[#lineColors + 1] = color
  end

  -- 提示：已经下过单，但这条网络里该物品仍是 0 —— 多半是"货送到别处了"或"这东西不在查询器连的网络上"
  if state.networkOk then
    for _, rule in ipairs(config.rules) do
      local have = state.inventory[rule.item] or 0
      local inflight = state.ledger[rule.item] or 0
      if have == 0 and inflight > 0 then
        lines[#lines + 1] = fit("hint: ordered but 0 in this net", limit)
        lineColors[#lineColors + 1] = colors.orange
        break
      end
    end
  end

  if state.notice then
    lines[#lines + 1] = fit("last: " .. state.notice, limit)
    lineColors[#lineColors + 1] = colors.cyan
  end

  local okRender = pcall(function()
    display.clear()
    if canColor then
      display.setTextColour(colors.white)
    end
    local contentLimit = showButtons and (height - buttonReserve) or height
    for y, line in ipairs(lines) do
      if y > contentLimit then
        break
      end
      display.setCursorPos(1, y)
      if canColor then
        display.setTextColour(lineColors[y] or colors.white)
      end
      display.write(line)
    end

    if showButtons and buttonReserve >= 2 then
      -- 倒数第二行：触摸反馈 / 操作提示（矮显示器会省掉这行）
      display.setCursorPos(1, height - 1)
      if canColor then
        display.setTextColour(colors.lightGrey)
      end
      display.write(fit(state.touchMsg or "buttons: order / auto / target - / +", limit))
      if canColor then
        display.setTextColour(colors.white)
      end
    end

    if showButtons then
      -- 最后一行：按钮（反色绘制，触摸坐标就是这里的 x/y）
      state.buttons = buildButtons(height, width)
      for _, btn in ipairs(state.buttons) do
        display.setCursorPos(btn.x, btn.y)
        display.setBackgroundColour(btn.bg)
        display.setTextColour(btn.fg)
        display.write(btn.label)
      end
      display.setBackgroundColour(colors.black)
      display.setTextColour(colors.white)
    else
      state.buttons = {}
    end

    if display.update then
      display.update()   -- Create_DisplayLink 需要显式刷新
    end
  end)
  if not okRender then
    display, displayKind = term, "term"
    state.buttons = {}
  end
end

-- 启动自检：地址（非 ASCII 会被 CC:T 传坏；请求器现有地址与配置是否一致）
local function checkAddresses()
  if not requester then
    return
  end
  local okAddr, current = pcall(requester.getAddress)
  if not okAddr then
    return
  end
  current = tostring(current or "")
  for _, rule in ipairs(config.rules) do
    local want = rule.address
    if want then
      if want:find("[\128-\255]") and config.setAddressOnOrder ~= false then
        log("WARNING: address %q contains non-ASCII characters. CC:T passes Lua strings to Java as bytes, "
          .. "so it WILL arrive mangled (seen in practice: the requester's address field turns into garbage). "
          .. "Use an ASCII address, or keep setAddressOnOrder=false and set it in the requester GUI.", want)
      end
      if config.setAddressOnOrder == false and current ~= want then
        log("note: requester address is currently %q but config says %q. With setAddressOnOrder=false "
          .. "the program will NOT overwrite it - make sure the requester GUI holds the right address.",
          current, want)
      end
    end
  end
end

-- 主循环 -------------------------------------------------------------------
loadState()
applyOverrides()
rebind()

local relayCount = 0
for _ in pairs(relays) do
  relayCount = relayCount + 1
end

log("stock_controller v%s starting (%d rules, poll %ds)", VERSION, #config.rules, POLL)
log("display: %s (%s)", tostring(state.displayName or "term"), displayKind)

local okSize, displayWidth, displayHeight = pcall(display.getSize)
if okSize then
  log("display size %dx%d (compact layout when width <30)", displayWidth, displayHeight)
else
  log("cannot read display size, falling back to the computer screen")
end

log("ticker: %s | requester: %s | relays: %d",
  tostring(state.tickerName or "none"), requester and "connected" or "none", relayCount)

checkAddresses()

-- 按钮需要高级显示器：普通显示器不会上报 monitor_touch
if displayKind == "monitor" then
  local okColour, isColour = pcall(display.isColour)
  if okColour and isColour == false then
    log("note: this is a NORMAL monitor - touch buttons need an ADVANCED monitor to work")
  else
    log("touch buttons enabled (order / auto / target - / +) on the monitor's bottom row")
  end
end

local timer = os.startTimer(POLL)
while true do
  local event, a, b, c = os.pullEvent()

  if event == "terminate" then
    log("terminate received; saving state and exiting")
    shutdownSignals()
    saveState()
    break
  elseif event == "timer" and a == timer then
    state.elapsed = state.elapsed + POLL
    local ok, err = pcall(refreshInventory)
    if not ok then
      state.networkOk = false
      state.lastError = tostring(err)
      log("inventory read failed: " .. state.lastError)
    else
      decide()
      applySignals()
    end
    render()
    timer = os.startTimer(POLL)
  elseif event == "monitor_touch" then
    -- 事件参数：显示器外设名, x, y（见 tweaked.cc/event/monitor_touch.html）
    if state.displayName == "?" or state.displayName == "none" or a == state.displayName then
      handleTouch(b, c)
      render()   -- 立刻刷新，让反馈看得见
    end
  elseif event == "peripheral" or event == "peripheral_detach" then
    log(("peripheral change (%s %s), rebinding"):format(event, tostring(a)))
    rebind()
  elseif event == "package_sent" or event == "package_received" then
    -- 事件参数：外设挂载名, Package 对象（见 FrogportPeripheral / PostboxPeripheral）
    reconcilePackage(b)
  end
end
