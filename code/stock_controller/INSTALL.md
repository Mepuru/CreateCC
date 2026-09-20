# 安装说明 —— 把文件放进游戏里的电脑

## 0. 放在哪个文件夹？

**不是** Windows 的文件夹，而是**游戏里那台 CC 电脑自己的文件系统**：

| Windows（本仓库） | 游戏电脑内部路径 |
|---|---|
| `code/stock_controller/config.lua` | `/stock_controller/config.lua` |
| `code/stock_controller/main.lua` | `/stock_controller/main.lua` |

- `/` 是电脑的根目录（`rom` 是只读系统盘）。
- 两个文件**必须在同一目录**：`main.lua` 里用 `require("config")`，它按当前程序所在目录解析。
- 目录名随便改，但两个文件要一起移动，运行时的命令也要跟着改（例：`stock_controller/main`）。

---

## 1. 方式 A：Ctrl+V 粘贴（推荐，不需要联网）

CC:T 支持把**系统剪贴板**粘贴进终端（触发 `paste` 事件，见 `docs/cc-tweaked/doc/events/paste.md`）。

1. 在电脑 shell 里建目录：
   ```
   mkdir /stock_controller
   ```
2. 开始编辑配置文件：
   ```
   edit /stock_controller/config.lua
   ```
3. 切到 Windows，用记事本打开 `config.lua` → `Ctrl+A` `Ctrl+C`。
4. 回到游戏，在 `edit` 界面按 **Ctrl+V** 粘贴；长文件耐心等它刷完。
5. 按 **Ctrl** 打开菜单 → 选 **Save** → 再 **Ctrl** → **Exit**（`edit` 的菜单项就是 Save / Run / Print / Exit）。
6. 同样流程粘贴 `main.lua`：
   ```
   edit /stock_controller/main.lua
   ```
7. 检查：
   ```
   ls /stock_controller
   ```
   应看到 `config.lua` 和 `main.lua` 两个文件。

> 粘贴中途出错（缺行/多行）就 `rm /stock_controller/main.lua` 后重新 `edit` 粘贴一遍，别在半成品上改。

---

## 2. 方式 B：让电脑自己下载（需要电脑能上网）

CC:T 自带 `wget` 与 `pastebin`（在 ROM 的 `http` 子目录里，shell 里直接敲名字即可）：

```
wget <你的URL> /stock_controller/main.lua
wget <你的URL> /stock_controller/config.lua
:: 或者
pastebin get <pastebin代码> /stock_controller/config.lua
```

- 文件可以先传到 GitHub raw / 自己的 web 服务 / pastebin。
- 服务端要允许 http：CC:T 默认允许公网域名、默认拒绝私有/本地 IP（拒绝时 `wget` 会报 `Domain not permitted`）。
  相关设置在存档的 `serverconfig/computercraft-server.toml`。

---

## 3. 方式 C：软盘/磁盘拷贝

适合"已经有一台电脑装好了，要复制到第二台"：

1. 在源电脑上把文件写到磁盘（`drive` 程序挂载，磁盘挂载点通常是 `/disk`）：
   ```
   cp /stock_controller/* /disk/stock_controller/
   ```
   （`ls`/`cp`/`mv`/`rm` 都是 ROM 里注册的别名，见 `/rom/startup.lua`）
2. 把磁盘拿到目标电脑，`drive` 挂载后：
   ```
   mkdir /stock_controller
   cp /disk/stock_controller/main.lua /stock_controller/
   cp /disk/stock_controller/config.lua /stock_controller/
   ```

> 注意：磁盘里也得先有文件，所以第一次还是得用方式 A 或 B。

---

## 3.5 外设怎么连到电脑（最常见的卡点）

Create 的方块要成为 **CC 外设**，必须满足**两个互相独立的条件**：

1. **Create 物流网络**：库存查询器 / 红石请求器要**加入仓库那条物流网络**——
   做法见下面的 **§3.6**（**不是**用"频率"物品！）
2. **CC:T 外设连接**：方块要么**贴着电脑**（任意一面），要么**和电脑在同一条有线 modem 网络**上
   —— 这决定电脑能不能"看见"它。

> ⚠️ **无线（Ender）modem 不能远程访问外设**：它只提供 `rednet` 消息收发。
> 远程外设必须用 **有线调制解调器（Wired Modem）+ 网络线（Networking Cable）**。

有线接法：

```
[库存查询器] ← 右键在它表面贴一个「有线调制解调器」
      │
   网络线
      │
[有线调制解调器] → [电脑]  ← 高级显示屏贴电脑右侧
```

- 电脑旁边放一个有线调制解调器（贴着电脑的任意一面即可）；
- 库存查询器上**右键贴**一个有线调制解调器（像插火把一样贴在它表面），这一步才会把该方块"挂"到网络上；
- 两者之间铺网络线连通；
- 在电脑里验证：
  ```
  for _,n in ipairs(peripheral.getNames()) do print(n, peripheral.getType(n)) end
  ```
  看到 `Create_StockTicker` 才算连上（屏幕上会从 `NET: NO TICKER` 变成正常数字）。
- 程序会自己重绑：接线过程中它会监听 `peripheral` 事件，接好后下一轮（2 秒）就会读到库存，不必重启。

## 3.6 怎么把库存查询器接进仓库网络（★ 最容易搞错的一步）

Create 6.0 的物流网络**不是**用「频率（Frequency）」物品绑的——那个物品属于**红石链接**系统。
物流网络靠"**可调谐物品**"（`LogisticallyLinkedBlockItem`：**打包机链接 Stock Link**、
红石请求器、工厂仪表）来复制/粘贴网络 ID：

1. 拿一个**打包机链接（Stock Link）的物品**（没调谐过的，普通外观）；
2. **右键仓库里那个正在工作的 Stock Link 方块** → 物品被"调谐"（变成金色附魔光效，提示"已连接"）
   （源码：`LogisticallyLinkedBlockItem.useOn()` 第 106-112 行：未调谐时把该方块的网络 UUID 复制进物品）；
3. 拿这个已调谐的物品**右键你的库存查询器** → 网络写进查询器
   （源码：`StockTickerBlock.useItemOn()` 第 62 行把"手持此类物品"的右键**透传**给物品处理，就是给已放好的查询器补绑用的）；
4. 或更省事：**先用调谐好的物品放置查询器**——游戏内教程原话就是"**放置前**右键一个库存链接站以连接到其网络"。

验证：屏幕状态行会在 2 秒内从 `NET: EMPTY NETWORK (freq?)` 变成真实数字。
若一直是 EMPTY NETWORK，就是这一步没做对（或仓库所在区块没加载）。

## 4. 运行
```
stock_controller/main
```

或

```
cd /stock_controller
main
```

启动时会打印自检信息，用来确认装对了：

```
[stock] stock controller up: 1 rules, poll 2s, display=monitor (monitor_0)
[stock] display size 29x16 (compact layout when width <30)
[stock] ticker: Create_StockTicker | requester: connected | relays: 0
```

## 5. 开机自启（可选）

```
edit /startup.lua
```
写入一行：
```lua
shell.run("stock_controller/main")
```
程序内部已经兜了 `pcall` 并处理 `terminate`，但自启程序崩溃仍可能挡住 shell，建议先手动跑通再自启。

## 6. 更新文件

覆盖旧文件最稳的做法是先删再粘：

```
rm /stock_controller/main.lua
edit /stock_controller/main.lua     :: 重新 Ctrl+V 粘贴新版
```

## 7. 排错对照

| 现象 | 原因 |
|---|---|
| `module 'config' not found` | 两个文件不在同一目录，或文件名不是 `config.lua` |
| 屏幕所有物品数量为 0（旧版）或 `NET: EMPTY NETWORK (freq?)` | 查询器**没接入仓库那条物流网络**（不是"频率"问题）→ 见 §3.6；也可能是仓库区块没加载 |
| `下单失败 ... 没有红石请求器` | 请求器没贴着电脑/没接 modem，或它没在这条物流网络上（同样用 Stock Link 物品调谐） |
| 屏幕是灰阶 | 用的是**普通显示器**，只有高级显示器才有 16 色（文字状态仍可读） |
| `显示屏尺寸：...` 很小、行被截断 | 显示器太小；程序会自动用紧凑排版，或把 `display.widthLimit` 调小 |
| 屏幕出现方块/问号/乱码 | **CC 终端与显示器画不出汉字**（CC:T 只带位图字体，无 Unicode 字形）；显示文本一律 ASCII，中文只能当**数据**用（如 `address = "经验"`） |
| 文件名/路径里出现中文 | 路径保持 ASCII；`item`/`address` 里的中文是数据，没问题 |
