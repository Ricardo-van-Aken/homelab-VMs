#!/usr/bin/env python3
"""Render JUnit XML files as a Markdown table for the GitHub step summary.

Usage: junit-summary.py <title> <dir>...
Writes to $GITHUB_STEP_SUMMARY when set, else stdout. Exits 0 always; the
test step itself decides pass or fail.
"""
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def suites(paths):
    for root in paths:
        # The junit callback names files <playbook>-<timestamp>.xml; order by
        # time so the molecule sequence reads top to bottom.
        for f in sorted(Path(root).rglob("*.xml"), key=lambda p: p.stem.rsplit("-", 1)[-1]):
            tree = ET.parse(f)
            top = tree.getroot()
            found = [top] if top.tag == "testsuite" else top.iter("testsuite")
            for s in found:
                yield f, s


def main(title, paths):
    lines = [f"## {title}", "", "| Playbook | Tasks | Failed | Skipped | Time |", "|---|---:|---:|---:|---:|"]
    failed_cases = []
    total = failures = 0
    for f, s in suites(paths):
        name = s.get("name") or f.stem
        tests, fails = int(s.get("tests", 0)), int(s.get("failures", 0)) + int(s.get("errors", 0))
        skipped, secs = int(s.get("skipped", 0)), float(s.get("time", 0))
        total, failures = total + tests, failures + fails
        mark = "❌" if fails else "✅"
        lines.append(f"| {mark} {name} | {tests} | {fails} | {skipped} | {secs:.0f}s |")
        for case in s.iter("testcase"):
            for kind in ("failure", "error"):
                for node in case.findall(kind):
                    msg = (node.get("message") or node.text or "").strip().splitlines()
                    failed_cases.append((case.get("classname", ""), case.get("name", ""), msg[0] if msg else ""))
    if total == 0:
        lines.append("| _no results found_ | | | | |")
    lines += ["", f"**{total} tasks, {failures} failed**"]
    if failed_cases:
        lines += ["", "### Failures", ""]
        lines += [f"- **{c}** › {n}: `{m}`" for c, n, m in failed_cases]
    out = "\n".join(lines) + "\n"
    dest = os.environ.get("GITHUB_STEP_SUMMARY")
    if dest:
        with open(dest, "a", encoding="utf-8") as fh:
            fh.write(out)
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
