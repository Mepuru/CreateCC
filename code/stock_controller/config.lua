--[[- 仓库控制器配置（改这个文件就行，不用动 main.lua）

部署位置：与 main.lua 同目录，例如
  /stock_controller/main.lua
  /stock_controller/config.lua

字段说明：
  item        物品 id，例如 "minecraft:iron_ingot"
  label       显示在屏幕上的短标签（**默认用 ASCII**，中文能不能显示取决于你的显示屏/字符集，见 README）
  low         低于这个数量就下单
  high        补到至少这个数量（同时用作滞回上限：达到 high 才清除"在途"账本）
  batch       每次下单数量（不填则用 high - low）
  address     目标蛙港/邮筒的物流地址字符串
  craft       true = 用红石请求器走"自动合成"下单；false = 普通请求
  batches     仅 craft=true 时用：合成批次数（对应 setCraftingRequest 的第一个参数）
  cooldown    覆盖全局冷却（秒），防止同一物品反复下单
  signal      可选：红石输出（电脑自带 redstone API 或 redstone_relay）
              { peripheral = nil(电脑自身) 或 "redstone_relay_0", side = "left", lowLevel = 15 }
]]

local config = {}

---- 基本设置 ----------------------------------------------------------------

-- 轮询间隔（秒）。stock() 每次返回整张网络并跑在服务端主线程，1~2 秒足够，别设太小。
config.pollInterval = 2

-- 同一物品两次下单的最小间隔（秒）
config.cooldown = 30

-- 下单时用哪个 API：
--   "auto"      → 有红石请求器就用它，否则用库存查询器的 requestFiltered
--   "ticker"    → 强制用 ticker.requestFiltered（无自动合成）
--   "requester" → 强制用红石请求器（找不到就报错）
config.orderVia = "auto"

-- 状态文件（记录"在途"账本，重启不丢）
config.stateFile = "/stock_controller/state.tbl"

-- 是否用蛙港/邮筒的 package_sent / package_received 事件核销在途
config.reconcilePackages = true

-- 是否由程序给请求器写地址：
--   false（默认）= 不写。**推荐**——请直接在红石请求器的 GUI 里填地址。
--     原因：CC:T 把 Lua 字符串按字节传给 Java，**非 ASCII（中文）会失真**，
--     程序写 "经验" 会让请求器地址栏变乱码、包裹送不到目的地（实测踩过）。
--   true = 由程序写。此时 address 必须是**纯 ASCII**（例如 "exp"），
--     并且 frogport 的地址也要在它 GUI 里改成同一个 ASCII 串。
config.setAddressOnOrder = false

-- 读到"整张网络一件物品都没有"时怎么处理：
--   true（默认）= 当成"读不到"（屏幕显示 ?、不下单）——空网络通常意味着查询器没接入仓库网络，
--                 或仓库区块没加载；当成 0 会导致每 30 秒重复下单
--   false       = 当真（确实存在"空仓库"场景时才关掉）
config.emptyMeansUnknown = true

-- 在途账本超时（秒）：下了单但一直没到货时，账本会永远挂着让程序不再下单。
-- 设成 >0 后，到达该秒数就把账本清零并告警一次（排查用；确认流程正常后建议关回 0）。
config.inflightTimeout = 0

-- 显示屏按钮：高级显示器最后一行会画 [ORDER] [AUTO] [LOW-] [LOW+]
--   [ORDER] 立刻下单一次（3 秒防连点）／[AUTO] 自动补货开关／
--   [LOW-] [LOW+] 现场调目标阈值（high 跟着平移），步长就是下面这个值
-- 注意：按钮改过的阈值与 AUTO 开关会**存进状态文件**（stateFile），重启后仍生效；
--       想恢复 config.lua 里的原始数值，删掉状态文件即可（rm /stock_controller/state.tbl）。
config.buttonLowStep = 1024

-- 程序退出（Ctrl+T）时怎么处理红石输出：
--   "hold"  = 保持现状（推荐：红石是"库存不足"的告警，不希望在停机时被清掉）
--   "clear" = 全部归零
config.signalOnExit = "hold"

-- 显示屏设置
config.display = {
  kind = "monitor",     -- CC 显示器（会用颜色）；可选 "display_link" / "term" / "auto"
  title = "STOCK CONTROL",  -- 标题：必须是 ASCII（CC:T 只带位图字体，终端/显示器画不出汉字）
  color = true,         -- monitor 上用红/黄/绿标状态
  widthLimit = 40,      -- 行宽上限；实际还会按显示器真实宽度自适应（窄屏自动换紧凑排版）
}

---- 规则表 ------------------------------------------------------------------

config.rules = {
  {
    -- 虫蚀石头（Infested Stone）——注意**不是**虫蚀石砖！
    --   minecraft:infested_stone         = 虫蚀石头  ← 就是这个
    --   minecraft:infested_stone_bricks  = 虫蚀石砖
    -- （两个 id 都已从客户端 jar 的 en_us.json 核对）
    item = "minecraft:infested_stone",
    label = "Infested Stone",     -- 显示用标签：必须 ASCII（中文画不出来）
    low = 8192,                   -- 低于 8K 就补货（你习惯常备 10K 左右）
    high = 10240,                 -- 补到 10K 算够（同时是滞回上限：达到它才清空在途账本）
    batch = 1024,                 -- 每次下单 1024（= 4 槽 × 256）；请求器最多 9 槽，代码会自动分摊
    -- 地址：字符串本身可以是中文，但 **不要让程序写**（setAddressOnOrder = false），
    -- 请在红石请求器的 GUI 里填好目的地；这个字段现在只用于日志/兜底路径。
    address = "经验",
    craft = false,                -- 虫蚀石头不是合成品；除非你的包里有配方
    -- batches = 1,               -- 仅 craft = true 时用
    signal = { side = "left", lowLevel = 15 },  -- 库存不足时电脑 left 面输出 15
  },
  --[[ 加更多物品就照上面复制一条
  {
    item = "minecraft:iron_ingot", label = "Iron Ingot",
    low = 256, high = 768, batch = 256, address = "exp",
    craft = false, signal = { side = "right", lowLevel = 15 },
  },
  ]]
}

return config
