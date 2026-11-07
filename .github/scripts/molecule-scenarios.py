#!/usr/bin/env python3
"""Pick the Molecule scenarios a change affects.

Reads changed file paths (one per line) on stdin and prints the scenarios to
run as a JSON list. With --all, prints every scenario. Writes the reason for
each pick to $GITHUB_STEP_SUMMARY when that is set.

A scenario runs when a file it depends on changed: its own directory, a role
it applies (from converge.yml) or any role those depend on (meta/main.yml),
or a file every scenario shares.
"""

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOLECULE = ROOT / "ansible" / "molecule"
ROLES = ROOT / "ansible" / "roles"

# Changes here affect every scenario.
SHARED = (
    ".config/molecule/",
    ".github/scripts/molecule-scenarios.py",
    ".github/workflows/build-image.yml",
    ".github/workflows/molecule.yml",
    "ansible/ansible.cfg",
    "ansible/docker/molecule-target/",
    "ansible/docker/runtime/",
    "ansible/molecule/prepare.yml",
    "ansible/requirements.yml",
)

ITEM = re.compile(r"^(\s*)-\s+(?:role:\s*)?([A-Za-z0-9_.]+)\s*(?:#.*)?$")


def listed_roles(path: Path, key: str) -> list[str]:
    """Role names listed under `key:` (roles: or dependencies:)."""
    if not path.is_file():
        return []
    names, indent = [], None
    for line in path.read_text().splitlines():
        if indent is None:
            match = re.match(rf"^(\s*){key}:\s*$", line)
            if match:
                indent = len(match.group(1))
            continue
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        match = ITEM.match(line)
        if match:
            names.append(match.group(2))
    return names


def role_dirs() -> dict[str, Path]:
    """Own roles by name; they live in roles/<group>/<role>."""
    return {p.name: p for p in ROLES.glob("*/*") if (p / "tasks").is_dir()}


def closure(roles: list[str], dirs: dict[str, Path]) -> set[str]:
    """The roles plus everything they depend on, own roles only."""
    seen, todo = set(), list(roles)
    while todo:
        role = todo.pop()
        if role in seen or role not in dirs:
            continue
        seen.add(role)
        todo += listed_roles(dirs[role] / "meta" / "main.yml", "dependencies")
    return seen


def main() -> None:
    scenarios = sorted(p.parent.name for p in MOLECULE.glob("*/molecule.yml"))
    reasons: dict[str, list[str]] = {}

    if "--all" in sys.argv:
        reasons = {s: ["run by hand: all scenarios"] for s in scenarios}
    else:
        dirs = role_dirs()
        uses = {
            s: closure(listed_roles(MOLECULE / s / "converge.yml", "roles"), dirs)
            for s in scenarios
        }
        for path in filter(None, (line.strip() for line in sys.stdin)):
            if path.startswith(SHARED):
                hits = scenarios
            elif path.startswith("ansible/molecule/"):
                hits = [s for s in scenarios if path.startswith(f"ansible/molecule/{s}/")]
            elif path.startswith("ansible/roles/"):
                parts = path.split("/")
                role = parts[3] if len(parts) > 3 else ""
                hits = [s for s in scenarios if role in uses[s]]
            else:
                hits = []
            for s in hits:
                reasons.setdefault(s, []).append(path)

    picked = sorted(reasons)
    print(json.dumps(picked))

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as out:
            out.write("### Molecule scenarios\n\n")
            if not picked:
                out.write("No change affects a scenario; nothing to run.\n")
            for s in picked:
                shown = reasons[s][:5]
                more = len(reasons[s]) - len(shown)
                out.write(f"- **{s}**: " + ", ".join(f"`{p}`" for p in shown))
                out.write(f" and {more} more\n" if more else "\n")


if __name__ == "__main__":
    main()
