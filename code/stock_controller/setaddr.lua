--[[- 查看 / 设置红石请求器的目的地地址

用法（在电脑上运行）：
    stock_controller/setaddr --show   :: **只读**：打印当前地址、字节长度与十六进制字节
    stock_controller/setaddr exp      :: 写入 ASCII 地址，并立刻读回校验

为什么用 `--show` 看十六进制：
  CC 终端画不出汉字，所以直接打印中文地址看不清。改成打印**字节**就能判断：
    - 界面里填的是 "经验"（UTF-8 6 字节）→ 期望看到 `#6  bytes: e7 bb 8f e9 aa 8c`
    - 若显示 `#2`（只剩两个字节）说明 Java→Lua 的转换把每个字符截成了一个字节（编码有损）
  这样不需要屏幕支持中文也能确认地址有没有设对。

说明：CC:T 把 Lua 字符串按字节交给 Java——**ASCII 一定无损**；非 ASCII（中文）实测会被写坏。
所以程序默认不写地址（`config.setAddressOnOrder = false`），由你在请求器的界面里填
（右键请求器，界面右下有地址输入框）。在那种方案下**只用 `--show`，不要用写入模式**。
]]

local want = ...

local requester = peripheral.find("Create_RedstoneRequester")
if not requester then
  print("no Create_RedstoneRequester peripheral - put it next to the computer or on the wired network")
  return
end

--- 把字符串按字节打印成十六进制（终端画不出中文，只能这样核验）
local function dumpBytes(s)
  local parts = {}
  for i = 1, #s do
    parts[#parts + 1] = ("%02x"):format(s:byte(i))
  end
  return table.concat(parts, " ")
end

if want == nil or want == "--show" or want == "-s" then
  local ok, current = pcall(requester.getAddress)
  if not ok then
    print("getAddress() failed: " .. tostring(current))
    return
  end
  if current == nil then
    print("current address: (nil - the block returned no value, i.e. it is empty)")
    return
  end
  local s = tostring(current)
  print(("current address: %q"):format(s))
  print(("  length: %d byte(s)"):format(#s))
  print(("  bytes : %s"):format(dumpBytes(s)))
  if #s == 0 then
    print("  -> EMPTY. The program will refuse to order (see the on-screen NET: NO ADDRESS message).")
  elseif #s == 6 then
    print("  -> looks like one CJK word in UTF-8 (6 bytes, e.g. 经验). Good.")
  elseif #s == 2 then
    print("  -> 2 bytes for 2 CJK chars: the Java->Lua conversion truncated them (encoding is lossy).")
  end
  return
end

-- 写入模式（只在你想让程序/这个工具管理 ASCII 地址时使用）
requester.setAddress(want)
local back = requester.getAddress()
if back == nil then
  print(("want %q  got nil (the block returned no value)"):format(want))
  return
end

print(("want %q  got %q  (#%d, match=%s)"):format(want, tostring(back), #tostring(back), tostring(back == want)))
if back == want then
  print("OK: round trip is lossless")
else
  print("MISMATCH: this string does not survive the Lua -> Java trip.")
  print("  -> use an ASCII address (rename the frogport too), or keep setAddressOnOrder=false")
  print("     and set the address inside the requester's own screen")
end
