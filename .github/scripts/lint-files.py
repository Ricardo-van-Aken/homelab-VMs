#!/usr/bin/env python3
"""Pick the files the Analysis workflow lints.

Reads changed file paths (one per line) on stdin and writes, as GitHub step
outputs (or to stdout outside Actions):

  run           true when there is anything to check
  yamllint      "all", or the changed YAML files, relative to the repo root
  ansible_lint  "all", or the changed Ansible YAML files, relative to ansible/
  syntax        true when an Ansible file changed

With --all, or when a lint setting or the analysis image changed, every
check covers everything. Writes what it picked to $GITHUB_STEP_SUMMARY.
"""

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# A change here re-checks everything.
EVERYTHING = (
    ".github/scripts/lint-files.py",
    ".github/workflows/analysis.yml",
    ".github/workflows/build-image.yml",
    "ansible/.ansible-lint",
    "ansible/ansible.cfg",
    "ansible/docker/analysis/",
    "ansible/requirements.yml",
)
# A change here re-runs yamllint on everything.
ALL_YAML = (".yamllint",)
# Not linted, as in ansible/.ansible-lint and .yamllint.
SKIPPED = ("ansible/docker/", "ansible/collections/", "ansible/galaxy_roles/", "ansible/.ansible/")


def is_yaml(path: str) -> bool:
    return path.endswith((".yml", ".yaml")) or Path(path).name == ".yamllint"


def main() -> None:
    changed = sorted({line.strip() for line in sys.stdin if line.strip()})
    everything = "--all" in sys.argv or any(p.startswith(EVERYTHING) for p in changed)

    # Deleted files are in the diff but have nothing left to lint.
    present = [p for p in changed if (ROOT / p).is_file()]
    yaml = [p for p in present if is_yaml(p) and not p.startswith(SKIPPED)]
    ansible = [p.removeprefix("ansible/") for p in yaml if p.startswith("ansible/")]

    out = {
        "yamllint": "all" if everything or any(p in ALL_YAML for p in changed) else " ".join(yaml),
        "ansible_lint": "all" if everything else " ".join(ansible),
        "syntax": str(everything or any(p.startswith("ansible/") for p in changed)).lower(),
    }
    out["run"] = str(any(out[k] for k in ("yamllint", "ansible_lint")) or out["syntax"] == "true").lower()

    target = os.environ.get("GITHUB_OUTPUT")
    with open(target, "a") if target else sys.stdout as sink:
        for key, value in out.items():
            sink.write(f"{key}={value}\n")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as note:
            note.write("### Analysis\n\n")
            if out["run"] == "false":
                note.write("No change needs linting; nothing to run.\n")
            for key, label in (("yamllint", "yamllint"), ("ansible_lint", "ansible-lint")):
                value = out[key] or "nothing"
                shown = value if value in ("all", "nothing") else f"{len(value.split())} changed file(s)"
                note.write(f"- {label}: {shown}\n")
            note.write(f"- syntax check: {'yes' if out['syntax'] == 'true' else 'no'}\n")


if __name__ == "__main__":
    main()
