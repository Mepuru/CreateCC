#!/usr/bin/env python3
"""从 Create 1.21.1 源码导出「原生 CC 外设」清单（类型名 / Lua 函数 / 事件）。

数据来源：docs/create-source/src/main/java/com/simibubi/create/compat/computercraft/
用途：版本升级后跑一次，和 docs/API_CREATE_NATIVE.md 比对，看有没有新增/改名/删除。

用法：
    python scripts/dump_create_peripherals.py
    python scripts/dump_create_peripherals.py --out docs/_generated_peripherals.txt

注意：事件名还可能来自枚举（源码里是 queueEvent(stpe.type.name, ...) 这种），
      完整事件名请对照 docs/create-wiki/src/users/cc-tweaked-integration/ 下的 Events 段。
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

RE_GET_TYPE = re.compile(r'getType\(\)\s*\{\s*return\s*"([^"]+)"')
RE_LUA_FUNCTION = re.compile(
    r"@LuaFunction(?:\([^)]*\))?\s*(?:@[A-Za-z]+(?:\([^)]*\))?\s*)"
    r"*public\s+[^(\r\n=]+?\s+(\w+)\s*\("
)
RE_QUEUE_EVENT = re.compile(r'queueEvent\(\s*"([a-z_]+)"')


def setup_stdout() -> None:
    """输出编码：交互式控制台沿用系统编码（GBK 控制台本来就能显示中文），
    重定向到文件时统一 UTF-8 —— 免得中文要么在控制台乱码、要么文件编码不一致。"""
    for stream in (sys.stdout, sys.stderr):
        try:
            if getattr(stream, "isatty", lambda: False)():
                stream.reconfigure(errors="replace")  # type: ignore[union-attr]
            else:
                stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, ValueError, OSError):
            pass

def dump(peripheral_dir: Path) -> int:
    print("# 由 scripts/dump_create_peripherals.py 生成 —— 请与 docs/API_CREATE_NATIVE.md 比对")
    print(f"# 时间：{datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print()

    files = sorted(peripheral_dir.glob("*.java"))
    if not files:
        print(f"# 没有找到任何 .java：{peripheral_dir}", file=sys.stderr)
        return 1

    for path in files:
        source = path.read_text(encoding="utf-8", errors="replace")

        type_match = RE_GET_TYPE.search(source)
        type_name = type_match.group(1) if type_match else "(无 getType，可能是基类)"

        fns = sorted(set(RE_LUA_FUNCTION.findall(source)))
        events = sorted(set(RE_QUEUE_EVENT.findall(source)))

        print(path.stem)
        print(f"  type   : {type_name}")
        print(f"  fns    : {', '.join(fns)}")
        if events:
            print(f"  events : {', '.join(events)}")
        print()

    print("# 提示：事件还可能来自枚举（如 queueEvent(stpe.type.name, ...)），")
    print("#       完整事件名请对照 docs/create-wiki/src/users/cc-tweaked-integration/ 下的 Events 段。")
    return 0


def main() -> int:
    setup_stdout()

    parser = argparse.ArgumentParser(description="从 Create 源码导出原生 CC 外设清单")
    parser.add_argument("--out", metavar="PATH",
                        help="把报告写到该文件（UTF-8，LF）；比用 > 重定向可靠 —— Windows PowerShell 5.1 的 > 会写成 UTF-16")
    args = parser.parse_args()

    if args.out:
        out_path = Path(args.out)
        if str(out_path.parent) not in ("", "."):
            out_path.parent.mkdir(parents=True, exist_ok=True)
        sys.stdout = out_path.open("w", encoding="utf-8", newline="\n")
        print(f"# 报告已写入 {out_path}（UTF-8）", file=sys.stderr)

    root = Path(__file__).resolve().parents[1]
    cc_root = root / "docs" / "create-source" / "src" / "main" / "java" / "com" / "simibubi" / "create" / "compat" / "computercraft"
    peripheral_dir = cc_root / "implementation" / "peripherals"

    if not peripheral_dir.is_dir():
        print(f"找不到源码：{peripheral_dir}", file=sys.stderr)
        print("先运行：python scripts/refresh_docs.py", file=sys.stderr)
        return 1

    return dump(peripheral_dir)


if __name__ == "__main__":
    raise SystemExit(main())
