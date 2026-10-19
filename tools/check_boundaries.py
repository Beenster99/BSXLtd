#!/usr/bin/env python3
"""Fails if a module reaches past another module's api/ folder, or uses a module it does
not list in its module.tres depends_on.

Rules (docs: the Core and UI module spec):
  - A module may use its own files freely.
  - Any module may use modules/core/api/ and modules/ui/api/.
  - Core may not use UI at all (Core is logic with no visuals).
  - Otherwise, modules/<x>/ may be used only through modules/<x>/api/, and only if x is in
    the user's depends_on.
  - A module's tests/ may use any module's api/ (loader and integration tests), never internals.
  - addons/ and shared/ are open to everyone (shared/void_salvage/ holds synced Void
    Salvage files).
  - No BSX class_name or autoload may reuse a class name from shared/void_salvage/, or the
    synced code stops compiling.

Both res:// paths and class_name identifiers are checked, since GDScript can reach a class
without a path. Usage:  python3 tools/check_boundaries.py [project_dir]
"""
import re
import sys
from pathlib import Path

OPEN_TO_ALL = {"core", "ui"}
PATH_RE = re.compile(r"res://modules/([a-z0-9_]+)/([^\"'\s)]*)")
CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
DEPENDS_RE = re.compile(r"^depends_on\s*=\s*PackedStringArray\(([^)]*)\)", re.M)
STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
COMMENT_RE = re.compile(r"#.*$", re.M)
SOURCE_EXTS = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}


def read_modules(root: Path) -> dict:
    modules = {}
    for manifest in sorted(root.glob("modules/*/module.tres")):
        text = manifest.read_text(encoding="utf-8")
        m = DEPENDS_RE.search(text)
        deps = re.findall(r'"([^"]+)"', m.group(1)) if m else []
        modules[manifest.parent.name] = set(deps)
    return modules


def read_classes(root: Path) -> dict:
    """class_name -> (module, is_public)."""
    classes = {}
    for f in root.glob("modules/*/**/*.gd"):
        rel = f.relative_to(root / "modules")
        for name in CLASS_RE.findall(f.read_text(encoding="utf-8")):
            classes[name] = (rel.parts[0], len(rel.parts) > 1 and rel.parts[1] == "api")
    return classes


AUTOLOAD_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)="\*?res://', re.M)


def name_clashes(root: Path) -> list:
    shared = {}
    for f in sorted(root.glob("shared/void_salvage/**/*.gd")):
        for name in CLASS_RE.findall(f.read_text(encoding="utf-8")):
            shared[name] = f.relative_to(root)
    ours = {}
    for f in sorted(root.glob("modules/**/*.gd")) + sorted(root.glob("tools/**/*.gd")):
        for name in CLASS_RE.findall(f.read_text(encoding="utf-8")):
            ours[name] = f"{f.relative_to(root)} (class_name)"
    project = root / "project.godot"
    if project.exists():
        text = project.read_text(encoding="utf-8")
        section = re.search(r"^\[autoload\]\n(.*?)(?=^\[|\Z)", text, re.M | re.S)
        for name in AUTOLOAD_RE.findall(section.group(1) if section else ""):
            ours[name] = "project.godot (autoload)"
    return [f"{where}: '{name}' is also a Void Salvage class ({shared[name]})"
            for name, where in sorted(ours.items()) if name in shared]


def allowed(user: str, target: str, public: bool, deps: set, in_tests: bool = False) -> str:
    """'' if allowed, else the reason it isn't."""
    if user == target:
        return ""
    if in_tests and public:
        return ""
    if user == "core" and target == "ui":
        return "core may not use ui"
    if not public:
        return f"reaches into {target}'s internals (only {target}/api/ is public)"
    if target in OPEN_TO_ALL or target in deps:
        return ""
    return f"uses {target}, which is not in its depends_on"


def check(root: Path) -> list:
    modules = read_modules(root)
    classes = read_classes(root)
    problems = []
    for user, deps in modules.items():
        for dep in sorted(deps):
            if dep not in modules:
                problems.append(f"modules/{user}/module.tres: depends on unknown module '{dep}'")
        for f in sorted((root / "modules" / user).rglob("*")):
            if f.suffix not in SOURCE_EXTS or not f.is_file():
                continue
            text = f.read_text(encoding="utf-8")
            rel = f.relative_to(root)
            in_tests = rel.parts[2] == "tests"
            scan = COMMENT_RE.sub("", text) if f.suffix == ".gd" else text
            for lineno, line in enumerate(scan.splitlines(), 1):
                for target, rest in PATH_RE.findall(line):
                    why = allowed(user, target, rest.startswith("api/"), deps, in_tests)
                    if why:
                        problems.append(f"{rel}:{lineno}: {why} (res://modules/{target}/{rest})")
            if f.suffix != ".gd":
                continue
            code = STRING_RE.sub('""', COMMENT_RE.sub("", text))
            for lineno, line in enumerate(code.splitlines(), 1):
                for word in set(re.findall(r"\b[A-Z][A-Za-z0-9_]*\b", line)):
                    if word not in classes:
                        continue
                    target, public = classes[word]
                    why = allowed(user, target, public, deps, in_tests)
                    if why:
                        problems.append(f"{rel}:{lineno}: {why} (class {word})")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
    problems = check(root) + name_clashes(root)
    for p in problems:
        print(p)
    if problems:
        print(f"{len(problems)} module boundary problem(s).")
        return 1
    print(f"Module boundaries OK ({len(read_modules(root))} modules).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
