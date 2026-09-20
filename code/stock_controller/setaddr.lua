--[[- 给红石请求器设置目的地地址，并**当场读回验证**（ASCII 是否无损 / 中文是否失真）

用法（在电脑上运行）：
    stock_controller/setaddr exp        :: 写入 ASCII 地址并读回校验
    stock_controller/setaddr 经验        :: 试试中文——想确认编码问题的就看这个的输出

输出形如：
    want "exp"  got "exp"  (#3, match=true)
    want "..."  got "..."  (#6, match=false)   ← match=false 就说明非 ASCII 会被传坏

为什么要单独做这个工具：
  CC:T 把 Lua 字符串按字节交给 Java。ASCII 一定无损；**非 ASCII（中文）会失真**（实测把请求器
  的地址栏写成了乱码）。这个脚本用 `#回读长度` 与 `回读 == 原值` 两个判据给出确定结论，
  不依赖屏幕能否显示汉字。

提醒：改完地址后，本程序若用 `config.setAddressOnOrder = false`（默认），自己不会再动地址。
]]

local want = ...
if type(want) ~= "string" or want == "" then
  print("usage: setaddr <address>")
  print("  e.g.  stock_controller/setaddr exp")
  print("        stock_controller/setaddr 经验     (to test the encoding)")
  return
end

local requester = peripheral.find("Create_RedstoneRequester")
if not requester then
  print("no Create_RedstoneRequester peripheral - put it next to the computer or on the wired network")
  return
end

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
  print("MISMATCH: CC:T does not pass this string through unchanged.")
  print("  -> use an ASCII address (rename the frogport too), or keep setAddressOnOrder=false")
  print("     and set the address inside the requester's GUI")
end
