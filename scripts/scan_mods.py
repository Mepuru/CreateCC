#!/usr/bin/env python3
"""扫描 Minecraft 实例的 mods 目录，输出与 CC: Tweaked / Create 相关的环境报告。

为什么需要它：Agent 写 Lua 程序前必须先知道"现场到底装了什么"——
外设类型名、可用的 API、是否有 CC:C Bridge / CCCCC / 其他 CC 插件，全都取决于真实 mod 列表，
而不是文档里的版本矩阵。

只依赖标准库（zipfile / json / re / argparse）。

用法：
    python scripts/scan_mods.py --mods "<你的实例目录>\\mods"
    python scripts/scan_mods.py --mods <mods目录> --full          # 额外列出全部 mod
    python scripts/scan_mods.py --mods <mods目录> > docs/_mods_scan.txt

判定「与 CC:T 有关」的依据（三条任一命中）：
    1) jar 内有包路径包含 computercraft（说明该 mod 写了 CC:T 集成代码）
    2) 元数据（neoforge.mods.toml / mods.toml / fabric.mod.json）里提到 computercraft 依赖
    3) mod id / 文件名命中关注名单（cc-tweaked、cccbridge、cc_sable 等）
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path

# mod id / 文件名里出现这些词，就归类为「CC:T 生态」
CC_HINTS = ("computercraft", "cc-tweaked", "cctweaked", "cc_tweaked", "cc-tweaked", "cccbridge", "cc_sable", "ccsable")
# 与 Create 生态相关的关注词
CREATE_HINTS = ("create", "flywheel", "ponder", "railways", "aeronautics", "sable", "copycats", "vanillin")

METADATA_NAMES = ("meta-inf/neoforge.mods.toml", "meta-inf/mods.toml", "fabric.mod.json")

RE_TOML_MODID = re.compile(r'^\s*modId\s*=\s*"([^"]+)"', re.M)
RE_TOML_VERSION = re.compile(r'^\s*version\s*=\s*"([^"]+)"', re.M)
RE_TOML_NAME = re.compile(r'^\s*displayName\s*=\s*"([^"]+)"', re.M)
RE_NEOFORGE_LIB = re.compile(r"net\.neoforged:neoforge:([0-9][^,;\s]*)")
RE_MC_LIB = re.compile(r"net\.minecraft:client:([0-9][^,;\s]*)")
# 启动器（PCL / HMCL / 官方）常见的几种写法
RE_MC_CLIENT_VERSION = re.compile(r'"clientVersion"\s*:\s*"([^"]+)"')
RE_NEOFORGE_ARG = re.compile(r'neoForgeVersion"?\s*,?\s*"?([0-9][0-9.]*)')
RE_NEOFORGE_MAVEN = re.compile(r"net/neoforged/neoforge/([0-9][^/\s\"]*)")


def setup_stdout() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, ValueError):
            pass


def instance_info(mods_dir: Path) -> dict:
    """从同级目录的 <实例名>.json 里读 MC / NeoForge 版本。"""
    info = {"instance": mods_dir.parent.name, "json": None, "minecraft": None, "neoforge": None}
    for path in mods_dir.parent.glob("*.json"):
        if path.stem != mods_dir.parent.name:
            continue
        info["json"] = str(path)
        raw = path.read_text(encoding="utf-8", errors="replace")
        for pattern in (RE_MC_CLIENT_VERSION, RE_MC_LIB):
            match = pattern.search(raw)
            if match:
                info["minecraft"] = match.group(1)
                break
        for pattern in (RE_NEOFORGE_ARG, RE_NEOFORGE_LIB, RE_NEOFORGE_MAVEN):
            match = pattern.search(raw)
            if match:
                info["neoforge"] = match.group(1)
                break
        break
    return info


def probe_jar(jar: Path) -> dict:
    entry = {
        "file": jar.name,
        "size_mb": round(jar.stat().st_size / 1_048_576, 2),
        "ids": [],
        "versions": [],
        "names": [],
        "cc_paths": 0,
        "cc_dep": False,
        "broken": False,
    }
    try:
        with zipfile.ZipFile(jar) as zf:
            names = zf.namelist()
            entry["cc_paths"] = sum(1 for n in names if "computercraft" in n.lower())
            for meta in names:
                if meta.lower() not in METADATA_NAMES:
                    continue
                try:
                    text = zf.read(meta).decode("utf-8", "replace")
                except (KeyError, OSError):
                    continue
                if "computercraft" in text.lower():
                    entry["cc_dep"] = True
                if meta.lower().endswith(".json"):
                    try:
                        data = json.loads(text)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(data, dict):
                        if data.get("id"):
                            entry["ids"].append(str(data["id"]))
                        if data.get("version"):
                            entry["versions"].append(str(data["version"]))
                        if data.get("name"):
                            entry["names"].append(str(data["name"]))
                        for dep in (data.get("depends") or {}):
                            if "computercraft" in str(dep).lower():
                                entry["cc_dep"] = True
                else:
                    entry["ids"] += RE_TOML_MODID.findall(text)
                    entry["versions"] += RE_TOML_VERSION.findall(text)
                    entry["names"] += RE_TOML_NAME.findall(text)
    except (zipfile.BadZipFile, OSError):
        entry["broken"] = True
    entry["ids"] = sorted(set(filter(None, entry["ids"])))
    entry["versions"] = sorted(set(filter(None, entry["versions"])))
    entry["names"] = sorted(set(filter(None, entry["names"])))
    return entry


def is_cc_related(entry: dict) -> bool:
    haystack = " ".join([entry["file"], *entry["ids"], *entry["names"]]).lower()
    return entry["cc_paths"] > 0 or entry["cc_dep"] or any(h in haystack for h in CC_HINTS)


def is_create_related(entry: dict) -> bool:
    haystack = " ".join([entry["file"], *entry["ids"], *entry["names"]]).lower()
    return any(h in haystack for h in CREATE_HINTS)


def fmt(entry: dict) -> str:
    ids = ", ".join(entry["ids"]) or "?"
    vers = ", ".join(entry["versions"]) or "?"
    names = " / ".join(entry["names"])
    flags = []
    if entry["cc_paths"]:
        flags.append(f"内含 computercraft 包路径 x{entry['cc_paths']}")
    if entry["cc_dep"]:
        flags.append("元数据依赖 CC:T")
    if entry["broken"]:
        flags.append("无法读取")
    suffix = f"   [{'; '.join(flags)}]" if flags else ""
    return f"  {entry['file']}\n      id={ids}  version={vers}" + (f"\n      name={names}" if names else "") + suffix


def main() -> int:
    setup_stdout()

    parser = argparse.ArgumentParser(description="扫描 MC 实例 mods 目录，报告 CC:T / Create 相关环境")
    parser.add_argument("--mods", required=True, help="mods 目录路径")
    parser.add_argument("--full", action="store_true", help="额外列出全部 mod（默认只列 CC/Create 相关）")
    args = parser.parse_args()

    mods_dir = Path(args.mods).expanduser()
    if not mods_dir.is_dir():
        print(f"找不到 mods 目录：{mods_dir}", file=sys.stderr)
        return 1

    jars = sorted(mods_dir.glob("*.jar"))
    info = instance_info(mods_dir)

    print("# Minecraft 实例环境扫描（scripts/scan_mods.py）")
    print(f"# mods 目录 : {mods_dir}")
    print(f"# 实例名    : {info['instance']}")
    if info["json"]:
        print(f"# 版本 json : {info['json']}")
    print(f"# Minecraft : {info['minecraft'] or '(未从 json 解析到，请看 mods 文件名)'}")
    print(f"# NeoForge  : {info['neoforge'] or '(未从 json 解析到)'}")
    print(f"# jar 数量  : {len(jars)}")
    print()

    entries = [probe_jar(j) for j in jars]
    cc = [e for e in entries if is_cc_related(e)]
    create = [e for e in entries if is_create_related(e) and not is_cc_related(e)]

    print(f"## CC:T 生态相关（{len(cc)} 个）")
    print("（这些 mod 决定可用外设类型名；写代码前必须逐个核对 docs/API_*.md）")
    for e in sorted(cc, key=lambda x: x["file"].lower()):
        print(fmt(e))
    print()

    print(f"## Create 生态相关（{len(create)} 个，不含上面已列的）")
    for e in sorted(create, key=lambda x: x["file"].lower()):
        print(fmt(e))
    print()

    if args.full:
        print(f"## 全部 mod（{len(entries)} 个）")
        for e in sorted(entries, key=lambda x: x["file"].lower()):
            ids = ", ".join(e["ids"]) or "?"
            vers = ", ".join(e["versions"]) or "?"
            print(f"  {e['file']}  |  id={ids}  version={vers}")
        print()

    print("# 下一步：")
    print("#   1) 把本报告要点写进 docs/ENVIRONMENT.md（版本矩阵 + 已装/未装的 CC 插件）")
    print("#   2) 与 docs/API_CREATE_NATIVE.md、docs/API_CCCBridge.md 对照，确认可用外设集合")
    print("#   3) 提醒用户：这是客户端 mods；联机时服务端也要有同样的 mod，外设由服务端提供")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
