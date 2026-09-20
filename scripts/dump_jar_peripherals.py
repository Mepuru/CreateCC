#!/usr/bin/env python3
"""挖出「这套整合包实际可用的 CC:T 集成面」——外设类型名、Lua ROM 附加、turtle 升级。

为什么需要它：Agent 写 Lua 前必须知道现场到底能调什么。CC:T 的集成面有三种，缺一不可：
    1) 外设方块：`peripheral.find("X")` 的 X；
    2) ROM 附加：`data/computercraft/lua/rom/apis/*.lua` 新增的**全局 API**，
       以及 `.../rom/modules/main/**.lua` 新增的 **require 模块**；
    3) turtle 升级：`data/*/computercraft/turtle_upgrade/*.json`。

Create 原生的外设可在 docs/API_CREATE_NATIVE.md 查到；其它 addon 注册了什么，只能从 jar 里挖。

只依赖标准库（zipfile / json / re / argparse）。

用法：
    python scripts/dump_jar_peripherals.py --mods "<你的实例目录>\\mods"
    python scripts/dump_jar_peripherals.py some-mod.jar
    python scripts/dump_jar_peripherals.py --mods <mods目录> > docs/_instance_peripherals.txt
    python scripts/dump_jar_peripherals.py --mods <mods目录> --include-computercraft   # 连 CC:T 本体一起挖

⚠️ 外设类型名是**候选**（同一个类里可能有同名字段/配置键）。最终以游戏内为准：
   for _,n in ipairs(peripheral.getNames()) do print(n, peripheral.getType(n)) end
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path

# 外设命名习惯：Create_XXX / XXX_YYY / xxx_yyy
RE_NAME_LIKE = re.compile(r"^(?:[A-Z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+|[a-z][A-Za-z0-9]*(?:_[a-z0-9]+)+)$")
# 明显是字段名/配置键的噪音
STOPWORDS = {
    "block_entity", "block_pos", "block_state", "item_stack", "item_handler", "fluid_stack",
    "server_level", "client_level", "save_data", "world_position", "compound_tag", "data_fix",
    "create_connected", "create_dragons_plus", "create_additional_logistics", "minecraft",
    "neoforge", "creative_mode", "game_time", "light_level", "random_source", "sound_event",
}

RE_GLOBAL_FN = re.compile(r"^function\s+([A-Za-z_][\w.]*)\s*\(", re.M)
RE_MODULE_MEMBER = re.compile(r"^(?:function\s+)?(?:local\s+)?([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*[=(]", re.M)
# CC:T 的 ROM 附加常用 LDoc 注释声明 API（实现是 Java native），这两条能把名字抓全
RE_LDOC_FN = re.compile(r"^---?\s*@function\s+([A-Za-z_][\w.:]*)", re.M)
RE_LDOC_MODULE = re.compile(r"^---?\s*@module\s+([\w.]+)", re.M)
RE_TURTLE_UPGRADE = re.compile(r"computercraft/turtle_upgrade/[^/]*\.json$", re.I)
RE_ROM_FILE = re.compile(r"(?:^|/)lua/rom/.+\.lua$", re.I)


def setup_stdout() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, ValueError):
            pass


def class_pool(data: bytes) -> dict[int, str] | None:
    """解析 class 常量池，返回 {常量池下标: UTF-8 字符串}。"""
    if len(data) < 10 or data[:4] != b"\xca\xfe\xba\xbe":
        return None
    total = int.from_bytes(data[8:10], "big")
    pos = 10
    pool: dict[int, str] = {}
    index = 1
    while index < total and pos < len(data):
        tag = data[pos]
        pos += 1
        if tag == 1:  # Utf8
            length = int.from_bytes(data[pos:pos + 2], "big")
            pos += 2
            pool[index] = data[pos:pos + length].decode("utf-8", "replace")
            pos += length
        elif tag in (3, 4):  # Integer / Float
            pos += 4
        elif tag in (5, 6):  # Long / Double（占两个槽位）
            pos += 8
            index += 1
        elif tag in (7, 8, 16, 19, 20):  # Class / String / MethodType / Module / Package
            pos += 2
        elif tag in (9, 10, 11, 12, 17, 18):  # Fieldref / Methodref / … / InvokeDynamic
            pos += 4
        elif tag == 15:  # MethodHandle
            pos += 3
        else:
            return None
        index += 1
    return pool


def class_pool_strings(data: bytes) -> list[str]:
    """解析 class 文件常量池，返回其中所有 UTF-8 字符串。"""
    pool = class_pool(data)
    return list(pool.values()) if pool else []


def _skip_member(pos: int, data: bytes) -> int | None:
    """跳过 field_info / method_info 的属性表，返回新位置。"""
    if pos + 2 > len(data):
        return None
    attr_count = int.from_bytes(data[pos:pos + 2], "big")
    pos += 2
    for _ in range(attr_count):
        if pos + 6 > len(data):
            return None
        length = int.from_bytes(data[pos + 2:pos + 6], "big")
        pos += 6 + length
    return pos if pos <= len(data) else None


def class_public_methods(data: bytes) -> list[str]:
    """列出 class 里 public、非构造、且带参数的方法名。

    对 CC:T 外设类来说，这些通常就是暴露给 Lua 的方法（**候选**，需用 probe 脚本核实）。
    """
    pool = class_pool(data)
    if not pool:
        return []
    pos = 10
    total = int.from_bytes(data[8:10], "big")
    # 重新走一遍常量池，跳过它
    index = 1
    while index < total and pos < len(data):
        tag = data[pos]
        pos += 1
        if tag == 1:
            length = int.from_bytes(data[pos:pos + 2], "big")
            pos += 2 + length
        elif tag in (3, 4):
            pos += 4
        elif tag in (5, 6):
            pos += 8
            index += 1
        elif tag in (7, 8, 16, 19, 20):
            pos += 2
        elif tag in (9, 10, 11, 12, 17, 18):
            pos += 4
        elif tag == 15:
            pos += 3
        else:
            return []
        index += 1

    if pos + 8 > len(data):
        return []
    pos += 6  # access_flags + this_class + super_class
    interfaces = int.from_bytes(data[pos:pos + 2], "big")
    pos += 2 + 2 * interfaces

    fields = int.from_bytes(data[pos:pos + 2], "big")
    pos += 2
    for _ in range(fields):
        if pos + 8 > len(data):
            return []
        pos += 6
        nxt = _skip_member(pos, data)
        if nxt is None:
            return []
        pos = nxt

    methods: list[str] = []
    if pos + 2 > len(data):
        return []
    method_count = int.from_bytes(data[pos:pos + 2], "big")
    pos += 2
    for _ in range(method_count):
        if pos + 8 > len(data):
            break
        access = int.from_bytes(data[pos:pos + 2], "big")
        name = pool.get(int.from_bytes(data[pos + 2:pos + 4], "big"), "")
        desc = pool.get(int.from_bytes(data[pos + 4:pos + 6], "big"), "")
        pos += 6
        if access & 0x0001 and desc.startswith("(") and name not in ("<init>", "<clinit>"):
            methods.append(name)
        nxt = _skip_member(pos, data)
        if nxt is None:
            break
        pos = nxt
    return sorted(set(methods))


def analyze_jar(jar: Path) -> dict | None:
    try:
        with zipfile.ZipFile(jar) as zf:
            names = zf.namelist()

            # 1) 外设类
            classes = [n for n in names if n.endswith(".class") and "computercraft" in n.lower()]
            peripherals: list[tuple[str, list[str]]] = []
            for name in classes:
                try:
                    data = zf.read(name)
                except (KeyError, OSError):
                    continue
                if b"getType" not in data:
                    continue
                strings = class_pool_strings(data)
                if "getType" not in strings:
                    continue
                cands = sorted({s for s in strings if RE_NAME_LIKE.match(s) and s not in STOPWORDS and len(s) <= 40})
                if cands:
                    peripherals.append((name, cands, class_public_methods(data)))

            packages: dict[str, int] = {}
            for name in classes:
                pkg = "/".join(name.split("/")[:-1])
                packages[pkg] = packages.get(pkg, 0) + 1

            # 2) Lua ROM 附加（全局 API + require 模块）
            rom: list[tuple[str, list[str], list[str], bool]] = []
            for name in names:
                if not RE_ROM_FILE.search(name):
                    continue
                try:
                    text = zf.read(name).decode("utf-8", "replace")
                except (KeyError, OSError):
                    continue
                globals_ = sorted(set(RE_LDOC_FN.findall(text)) | set(RE_GLOBAL_FN.findall(text)))
                members = sorted({f"{t}.{m}" for t, m in RE_MODULE_MEMBER.findall(text)})
                module = RE_LDOC_MODULE.search(text)
                if module:
                    members = [f"@module {module.group(1)}", *members]
                rom.append((name, globals_, members, "/apis/" in name))

            # 3) turtle 升级
            upgrades: list[tuple[str, str]] = []
            for name in names:
                if not RE_TURTLE_UPGRADE.search(name):
                    continue
                detail = ""
                try:
                    data = json.loads(zf.read(name).decode("utf-8", "replace"))
                    if isinstance(data, dict):
                        detail = str(data.get("type") or data.get("id") or data.get("upgrade") or "")
                except (KeyError, OSError, json.JSONDecodeError):
                    pass
                upgrades.append((name.split("/")[-1], detail))

            if not classes and not rom and not upgrades:
                return None
    except (zipfile.BadZipFile, OSError):
        return None

    return {
        "jar": jar.name,
        "class_count": len(classes),
        "packages": packages,
        "peripherals": peripherals,
        "rom": rom,
        "upgrades": upgrades,
    }


def report(results: list[dict], out) -> None:
    print("# 实例内 CC:T 集成面清单（scripts/dump_jar_peripherals.py）", file=out)
    print("# 1) 外设类型名 2) Lua ROM 附加（全局 API / require 模块） 3) turtle 升级", file=out)
    print("# ⚠️ 类型名是候选，最终以游戏内 peripheral.getType() 为准；Create 原生权威清单见 docs/API_CREATE_NATIVE.md", file=out)
    print(file=out)

    for res in results:
        print(f"## {res['jar']}", file=out)

        if res["peripherals"]:
            print("   [外设] 带 getType() 的类 → 类型名候选 / public 方法候选：", file=out)
            for cls, cands, methods in sorted(res["peripherals"]):
                print(f"     {cls.split('/')[-1]}: {', '.join(cands)}", file=out)
                if methods:
                    print(f"        方法候选: {', '.join(methods)}", file=out)
        if res["class_count"]:
            top = sorted(res["packages"].items(), key=lambda kv: (-kv[1], kv[0]))[:4]
            print("   [外设] 主要包：", file=out)
            for pkg, count in top:
                print(f"     {pkg}  ({count})", file=out)

        if res["rom"]:
            print("   [ROM] Lua 附加：", file=out)
            for name, globals_, members, is_api in sorted(res["rom"]):
                kind = "全局 API" if is_api else "模块"
                short = name.split("lua/rom/")[-1]
                detail = ", ".join(globals_) if globals_ else (", ".join(members[:8]) if members else "(无函数导出)")
                print(f"     [{kind}] {short}: {detail}", file=out)

        if res["upgrades"]:
            print("   [turtle] 升级：", file=out)
            for name, detail in res["upgrades"]:
                print(f"     {name}" + (f"  type={detail}" if detail else ""), file=out)

        if not (res["peripherals"] or res["rom"] or res["upgrades"]):
            print("   （只有 mixin/兼容代码，没有新增外设、ROM API 或 turtle 升级）", file=out)
        print(file=out)


def extract_rom(jar: Path, out_dir: Path) -> list[Path]:
    """把 jar 内 `lua/rom/**` 的 Lua/txt 文件抽到 out_dir，方便离线阅读真实 API。"""
    written: list[Path] = []
    with zipfile.ZipFile(jar) as zf:
        for name in zf.namelist():
            if not (RE_ROM_FILE.search(name) or "/lua/rom/" in name and name.endswith(".txt")):
                continue
            rel = name.split("lua/rom/")[-1]
            if not rel:
                continue
            target = out_dir / jar.stem.split("-")[0] / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(zf.read(name))
            written.append(target)
    return written


def main() -> int:
    setup_stdout()

    parser = argparse.ArgumentParser(description="挖出实例实际的 CC:T 集成面")
    parser.add_argument("jars", nargs="*", help="要分析的 jar 路径（可省略，用 --mods）")
    parser.add_argument("--mods", help="mods 目录：自动挑出含 computercraft 内容的 jar")
    parser.add_argument("--include-computercraft", action="store_true",
                        help="连 CC: Tweaked 本体一起挖（输出会非常吵，默认跳过）")
    parser.add_argument("--extract-rom", metavar="DIR",
                        help="把附加的 Lua ROM 文件（全局 API / 模块 / 帮助文本）抽到该目录")
    args = parser.parse_args()

    targets: list[Path] = [Path(p).expanduser() for p in args.jars]
    if args.mods:
        mods_dir = Path(args.mods).expanduser()
        if not mods_dir.is_dir():
            print(f"找不到 mods 目录：{mods_dir}", file=sys.stderr)
            return 1
        targets += sorted(mods_dir.glob("*.jar"))
    if not targets:
        parser.error("至少要给 jar 路径或 --mods 目录")

    if not args.include_computercraft:
        targets = [t for t in targets if "cc-tweaked" not in t.name.lower()]

    results = [r for r in (analyze_jar(j) for j in targets) if r]
    if not results:
        print("没有发现任何含 CC:T 集成内容的 jar。", file=sys.stderr)
        return 1

    report(results, sys.stdout)

    if args.extract_rom:
        out_dir = Path(args.extract_rom).expanduser()
        total = 0
        for jar in targets:
            try:
                written = extract_rom(jar, out_dir)
            except (zipfile.BadZipFile, OSError):
                continue
            if written:
                total += len(written)
                print(f"已抽取 {len(written)} 个 ROM 文件 ← {jar.name}", file=sys.stderr)
        print(f"# 共抽取 {total} 个附加 ROM 文件到 {out_dir}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
