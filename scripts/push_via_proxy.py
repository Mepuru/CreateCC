#!/usr/bin/env python3
"""在 github.com 直连不通（TCP 443 超时）的环境下，通过 gh-proxy 推送当前分支。

原理：git 的流量走 gh-proxy 转发，认证用 `gh auth token` 拿到的 token；
token 只放进环境变量 + 一个临时 askpass 脚本，**不会出现在命令行或输出里**，用完即删。

前置：本机装了 `gh` 且已 `gh auth login`；仓库已有 origin（用于识别 owner/name）。

用法：
    python scripts/push_via_proxy.py
    python scripts/push_via_proxy.py --branch main
    python scripts/push_via_proxy.py --proxy https://v6.gh-proxy.org/ --repo Mepuru/CreateCC

退出码：0 成功（并打印远端最新 commit 供核对）；1 失败。
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_PROXY = "https://v6.gh-proxy.org/"


def setup_stdout() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            if getattr(stream, "isatty", lambda: False)():
                stream.reconfigure(errors="replace")  # type: ignore[union-attr]
            else:
                stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, ValueError, OSError):
            pass


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", **kwargs)


def current_branch() -> str:
    proc = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    branch = proc.stdout.strip()
    if proc.returncode != 0 or not branch or branch == "HEAD":
        print("无法确定当前分支（请手动指定 --branch）", file=sys.stderr)
        raise SystemExit(1)
    return branch


def repo_slug(explicit: str | None) -> str:
    if explicit:
        return explicit
    proc = run(["git", "remote", "get-url", "origin"])
    match = re.search(r"github\.com[/:]([^/]+/[^/\s]+?)(?:\.git)?$", proc.stdout.strip())
    if not match:
        print("无法从 origin 解析 owner/repo（请用 --repo owner/name 指定）", file=sys.stderr)
        raise SystemExit(1)
    return match.group(1)


def github_token() -> str:
    proc = run(["gh", "auth", "token"])
    token = proc.stdout.strip()
    if proc.returncode != 0 or not token:
        print("拿不到 token：请先 `gh auth login`", file=sys.stderr)
        raise SystemExit(1)
    return token


def make_askpass(path: Path) -> None:
    """git 需要凭据时会调用 GIT_ASKPASS，这里让它回显环境变量里的 token。"""
    if os.name == "nt":
        path.write_text("@echo off\r\necho %GIT_TOKEN%\r\n", encoding="ascii")
    else:
        path.write_text("#!/bin/sh\nprintf '%s\\n' \"$GIT_TOKEN\"\n", encoding="ascii")
        path.chmod(0o700)


def main() -> int:
    setup_stdout()

    parser = argparse.ArgumentParser(description="通过 gh-proxy 推送分支（应对 github.com 直连不通）")
    parser.add_argument("--branch", help="要推送的分支（默认当前分支）")
    parser.add_argument("--repo", help="owner/name（默认从 origin 解析）")
    parser.add_argument("--proxy", default=DEFAULT_PROXY, help=f"代理前缀（默认 {DEFAULT_PROXY}）")
    args = parser.parse_args()

    branch = args.branch or current_branch()
    slug = repo_slug(args.repo)
    token = github_token()

    url = f"{args.proxy.rstrip('/')}/https://github.com/{slug}.git"

    with tempfile.TemporaryDirectory() as tmp:
        askpass = Path(tmp) / ("askpass.cmd" if os.name == "nt" else "askpass.sh")
        make_askpass(askpass)

        env = dict(os.environ)
        env["GIT_ASKPASS"] = str(askpass)
        env["GIT_TOKEN"] = token
        env["GIT_TERMINAL_PROMPT"] = "0"

        print(f"推送 {branch} → {slug}（经由 {args.proxy}）")
        proc = run(
            ["git", "-c", "credential.helper=", "-c", f"core.askpass={askpass}",
             "push", url, f"refs/heads/{branch}:refs/heads/{branch}"],
            env=env,
        )
        # git 把进度写到 stderr，这里只回显最后几行
        tail = [line for line in (proc.stdout + proc.stderr).splitlines() if line.strip()][-4:]
        for line in tail:
            print("  " + line)
        if proc.returncode != 0:
            print("推送失败", file=sys.stderr)
            return 1

    # 用 gh api 核对远端实际落地（gh 走 api.github.com，通常不受直连封锁影响）
    verify = run(["gh", "api", f"repos/{slug}/commits/{branch}", "--jq", ".sha"])
    if verify.returncode == 0 and verify.stdout.strip():
        print(f"远端 {branch} 现在指向 {verify.stdout.strip()[:7]}")
    else:
        print("（提示）无法用 gh api 核对远端，请自行到网页确认", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
