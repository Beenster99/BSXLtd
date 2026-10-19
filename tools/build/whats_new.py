#!/usr/bin/env python3
"""Drafts release/v<version>/whats_new.md from the pull requests merged since the previous
release tag, grouped by their module:<name> label. The draft is edited by hand before it is
posted: what players can now do, what was fixed, known issues.

Usage:
  python3 tools/build/whats_new.py --version 0.1.0 --out release/v0.1.0/whats_new.md
  python3 tools/build/whats_new.py --version 0.1.0 --prs prs.json   # offline / tests
Needs the GitHub CLI (gh) for the live list; GH_TOKEN in CI.
"""
import argparse
import json
import subprocess
import sys

MODULE_NAMES = {
    "core": "Core and UI", "ui": "Core and UI", "trades": "Trades",
    "ship_bay": "Ship and Bay", "contracts": "Contracts", "quality": "Quality and Inspection",
    "multiplayer": "Multiplayer", "business": "Business", "progression": "Progression",
    "shared_components": "Shared Components",
}


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def previous_tag(version):
    tags = run(["git", "tag", "--list", "v*", "--sort=-v:refname"]).stdout.split()
    return next((t for t in tags if t != f"v{version}"), None)


def merged_prs(since_tag):
    search = "is:merged"
    if since_tag:
        date = run(["git", "log", "-1", "--format=%cI", since_tag]).stdout.strip()
        if date:
            search += f" merged:>{date}"
    res = run(["gh", "pr", "list", "--state", "merged", "--search", search, "--limit", "300",
               "--json", "number,title,labels,url"])
    if res.returncode != 0:
        print(f"whats_new: gh failed, writing an empty draft: {res.stderr.strip()}", file=sys.stderr)
        return []
    return json.loads(res.stdout or "[]")


def group(prs):
    groups = {}
    for pr in prs:
        labels = [l["name"] if isinstance(l, dict) else l for l in pr.get("labels", [])]
        modules = [l.split(":", 1)[1] for l in labels if l.startswith("module:")]
        name = MODULE_NAMES.get(modules[0], modules[0]) if modules else "Other"
        groups.setdefault(name, []).append(pr)
    return groups


def render(version, prev, groups):
    lines = [f"# BSX Ltd v{version}", ""]
    lines += ["## What you can do now", "", "_Edit: one or two sentences, in players' words._", ""]
    lines += ["## Fixed", "", "_Edit: bugs players would have noticed._", ""]
    lines += ["## Known issues", "", "_Edit, or delete if there are none._", ""]
    since = f" since {prev}" if prev else ""
    lines += [f"## Changes by module{since}", ""]
    if not groups:
        lines += ["_No merged pull requests found._", ""]
    for name in sorted(groups, key=lambda n: (n == "Other", n)):
        lines.append(f"### {name}")
        for pr in groups[name]:
            lines.append(f"- {pr['title']} (#{pr['number']})")
        lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--out")
    ap.add_argument("--prs", help="read PRs from a JSON file instead of gh")
    args = ap.parse_args()
    prev = previous_tag(args.version)
    if args.prs:
        with open(args.prs, encoding="utf-8") as f:
            prs = json.load(f)
    else:
        prs = merged_prs(prev)
    text = render(args.version, prev, group(prs))
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)


if __name__ == "__main__":
    main()
