#!/usr/bin/env python3
"""刷新 docs/ 下的一手资料快照（走 gh-proxy 加速）。

对 4 个资料库执行 fetch + 重置到上游分支；sparse 配置保持与 docs/INDEX.md 记录一致。
所有 git 调用的输出都被捕获，只在检查点失败时报错，因此退出码可靠：
  0 = 全部成功，1 = 有仓库失败。

用法：
    python scripts/refresh_docs.py
    python scripts/refresh_docs.py --proxy https://v6.gh-proxy.org/

刷新后请按 AGENTS.md 第 8 节复核 API 变化。
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

DEFAULT_PROXY = "https://v6.gh-proxy.org/"

REPOS = [
    {
        "dir": "create-wiki",
        "branch": "main",
        "url": "https://github.com/Creators-of-Create/wiki",
        "sparse": [],
    },
    {
        "dir": "create-source",
        "branch": "mc1.21.1/dev",
        "url": "https://github.com/Creators-of-Create/Create",
        "sparse": [
            "src/main/java/com/simibubi/create/compat/computercraft",
            # 物流内部实现：库存摘要/打包机/频率网络/工厂仪表（用于理解"Create 自己怎么读库存"）
            "src/main/java/com/simibubi/create/content/logistics",
            # 相邻库存/流体的 capability 读取行为
            "src/main/java/com/simibubi/create/foundation/blockEntity/behaviour/inventory",
        ],
    },
    {
        "dir": "cc-tweaked",
        "branch": "mc-1.21.x",
        "url": "https://github.com/cc-tweaked/CC-Tweaked",
        "sparse": [
            "doc",
            "projects/core/src/main/java/dan200/computercraft/core/apis",
            "projects/core/src/main/resources/data/computercraft/lua/rom/apis",
        ],
    },
    {
        "dir": "cccbridge",
        "branch": "mc1.21.1",
        "url": "https://github.com/tweaked-programs/cccbridge",
        "sparse": [],
    },
]


def setup_stdout() -> None:
    """Windows 控制台默认不是 UTF-8，避免中文输出报 UnicodeEncodeError。"""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, ValueError):
            pass


def git(args: list[str], cwd: Path | None = None) -> str:
    """执行 git，返回 stdout（已 strip）。失败则打印输出并终止脚本。"""
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError:
        print("找不到 git：请先安装 Git 并确保它在 PATH 里。", file=sys.stderr)
        raise SystemExit(1)
    if proc.returncode != 0:
        print(f"  git {' '.join(args)} 失败（退出码 {proc.returncode}）", file=sys.stderr)
        for line in (proc.stdout + proc.stderr).splitlines():
            print(f"    {line}", file=sys.stderr)
        raise SystemExit(1)
    return proc.stdout.strip()


def sync_repo(repo: dict, docs_dir: Path, proxy: str) -> None:
    path = docs_dir / repo["dir"]
    url = proxy + repo["url"]
    sparse: list[str] = repo["sparse"]
    is_clone = not (path / ".git").exists()

    if is_clone:
        print(f"== 克隆 {repo['dir']}  ({repo['branch']})")
        clone_args = ["clone", "--depth", "1"]
        if sparse:
            clone_args += ["--filter=blob:none", "--sparse"]
        clone_args += ["--branch", repo["branch"], url, str(path)]
        git(clone_args)
    else:
        print(f"== 更新 {repo['dir']}  ({repo['branch']})")
        git(["-C", str(path), "remote", "set-url", "origin", url])
        git(["-C", str(path), "fetch", "--depth", "1", "origin", repo["branch"]])
        git(["-C", str(path), "checkout", "-B", repo["branch"], "FETCH_HEAD"])

    if sparse:
        git(["-C", str(path), "sparse-checkout", "set", *sparse])


def main() -> int:
    setup_stdout()

    parser = argparse.ArgumentParser(description="刷新 CreateCC 的 docs/ 资料快照")
    parser.add_argument("--proxy", default=DEFAULT_PROXY, help=f"git 加速前缀（默认 {DEFAULT_PROXY}）")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    docs_dir = root / "docs"
    docs_dir.mkdir(parents=True, exist_ok=True)

    for repo in REPOS:
        sync_repo(repo, docs_dir, args.proxy)

    print()
    print("== 当前快照 ==")
    for repo in REPOS:
        path = docs_dir / repo["dir"]
        head = git(["-C", str(path), "log", "-1", "--format=%h %ad", "--date=short"])
        branch = git(["-C", str(path), "rev-parse", "--abbrev-ref", "HEAD"])
        print(f"{repo['dir']:<14} {branch:<14} {head}")

    print()
    print("请更新 docs/INDEX.md 里的 commit 与日期，并按 AGENTS.md 第 8 节复核 API。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
