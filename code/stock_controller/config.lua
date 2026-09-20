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

-- 程序退出（Ctrl+T）时怎么处理红石输出：
--   "hold"  = 保持现状（推荐：红石是"库存不足"的告警，不希望在停机时被清掉）
--   "clear" = 全部归零
config.signalOnExit = "hold"

-- 显示屏设置
config.display = {
  kind = "monitor",     -- CC 显示器（会用颜色）；可选 "display_link" / "term" / "auto"
  title = "经验库存",    -- 标题（CC 显示器能显示中文）
  color = true,         -- monitor 上用红/黄/绿标状态
  widthLimit = 40,      -- 行宽上限；实际还会按显示器真实宽度自适应（窄屏自动换紧凑排版）
}

---- 规则表 ------------------------------------------------------------------

config.rules = {
  {
    -- 虫蚀石砖（1.21.1 官方 id，已从客户端 jar 语言文件核对：
    --   block.minecraft.infested_stone_bricks = Infested Stone Bricks）
    item = "minecraft:infested_stone_bricks",
    label = "Infested Bricks",   -- 想用中文就改成 "虫蚀石砖"（CC 显示器支持中文；Create 翻页屏不行）
    low = 128,                   -- ★ 待你确认：低于多少就补货
    high = 512,                  -- ★ 待你确认：补到多少算够（同时是滞回上限）
    batch = 256,                 -- ★ 每次下单数量；请求器单槽上限 256，超过会自动铺到多个槽（最多 9 槽 = 2304）
    address = "经验",             -- frogport 的物流地址（区分大小写，必须与游戏里设置的一致）
    craft = false,               -- 虫蚀石砖一般不是合成品；如果你的包里有配方可选 true
    -- batches = 1,              -- 仅 craft = true 时用
    signal = { side = "left", lowLevel = 15 },  -- 库存不足时电脑 left 面输出 15；换面/换继电器改这里
  },
  --[[ 加更多物品就照上面复制一条
  {
    item = "minecraft:iron_ingot", label = "Iron Ingot",
    low = 256, high = 768, batch = 256, address = "经验",
    craft = false, signal = { side = "right", lowLevel = 15 },
  },
  ]]
}

return config
