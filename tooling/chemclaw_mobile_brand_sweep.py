#!/usr/bin/env python3
"""Replace end-user DSH Go branding while preserving upstream provenance and protocols.

--write: rewrite source files, then run l10n_merge.py and guide_sync.py.
--check: refuse remaining visible names in the selected source directories.
This intentionally preserves dsh-go internal identifiers, app package dsh_app,
dshgo:// links, original author attribution, and LICENSE/THIRD_PARTY_NOTICES.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROVENANCE = {"app/lib/state/app_info.dart", "app/lib/ui/settings/about_page.dart"}


def sources():
    yield from (ROOT / "app/lib/l10n/parts").glob("*.arb")
    yield from (ROOT / "app/lib").rglob("*.dart")
    yield from (ROOT / "app/android/app/src/main").rglob("*.xml")
    yield from (ROOT / "app/android/app/src/main").rglob("*.kt")
    yield from (ROOT / "app/test").rglob("*.dart")
    yield from (ROOT / "docs/guide").rglob("*.md")


def set_message(text: str, key: str, value: str) -> str:
    pattern = r'(?m)^(\s*"' + re.escape(key) + r'": )"(?:\\.|[^"])*"(,?)$'
    updated, count = re.subn(pattern, lambda m: m[1] + json.dumps(value, ensure_ascii=False) + m[2], text, count=1)
    if count != 1:
        raise ValueError("missing localization key " + key)
    return updated


def transform(path: str, text: str) -> str:
    if path in PROVENANCE or "/l10n/gen/" in path:
        return text
    if path.startswith("app/lib/l10n/parts/") and path.endswith(".arb"):
        lines = []
        for line in text.splitlines(keepends=True):
            if '"hubAboutAuthor"' in line:
                lines.append(line)  # Keep factual original DSH Go author credit.
                continue
            line = line.replace("DSH Go", "ChemClaw").replace("DSH-Go", "ChemClaw")
            if '"searchKwAbout"' in line:
                line = line.replace("dsh-go", "chemclaw,dsh-go") if "chemclaw" not in line else line
            lines.append(line)
        text = "".join(lines)
        if path.endswith("/star_zh.arb"):
            text = set_message(text, "starPromptTitle",
                "{hours, plural, =0{你已使用 ChemClaw 半小时} =1{你已使用 ChemClaw 一小时} other{你已使用 ChemClaw {hours} 小时}}")
            text = set_message(text, "starPromptBody",
                "ChemClaw 手机版是开源项目。如果觉得好用，欢迎在 GitHub 给项目点个 Star，支持后续改进。")
            text = set_message(text, "starPromptPlea", "欢迎支持项目持续完善。")
        elif path.endswith("/star_en.arb"):
            text = set_message(text, "starPromptTitle",
                "{hours, plural, =0{You've used ChemClaw for half an hour} =1{You've used ChemClaw for an hour} other{You've used ChemClaw for {hours} hours}}")
            text = set_message(text, "starPromptBody",
                "ChemClaw Mobile is open source. If it helps, please consider starring the project on GitHub.")
            text = set_message(text, "starPromptPlea", "Thank you for supporting the project.")
        return text
    if path.startswith("docs/guide/"):
        # The original project remains named when it is explicitly credited.
        return "".join(line if re.search(r"original author|upstream|上游项目|原作者|原项目", line, re.I)
                       else line.replace("DSH Go", "ChemClaw")
                       for line in text.splitlines(keepends=True))
    return text.replace("DSH Go", "ChemClaw").replace("DSH-Go", "ChemClaw")


def main() -> int:
    parser = argparse.ArgumentParser()
    args = parser.add_mutually_exclusive_group(required=True)
    args.add_argument("--write", action="store_true")
    args.add_argument("--check", action="store_true")
    opts = parser.parse_args()
    dirty = []
    for path in sources():
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        current = path.read_text(encoding="utf-8")
        updated = transform(rel, current)
        if updated != current:
            dirty.append(rel)
            if opts.write:
                path.write_text(updated, encoding="utf-8")
    for rel in dirty:
        print(("Updated: " if opts.write else "Brand mismatch: ") + rel)
    print("ChemClaw branding: " + str(len(dirty)) + " changed/mismatching files")
    return 1 if opts.check and dirty else 0


if __name__ == "__main__":
    raise SystemExit(main())
