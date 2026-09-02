"""Apply the simulated "colleague's pull" to schema-model.

Copies the staged files under scripts/pull/ into schema-model/Tables/, which
switches schema-model from the pre-pull baseline to the post-pull state.

Run this AFTER create_before_pull_snapshot and BEFORE create_diff_development.

Usage: python scripts/apply_pull_edits.py [--revert]
  --revert  Restore schema-model to its checked-in state (git checkout the
            edited file, delete the new file).
"""

from __future__ import annotations
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
STAGED_DIR = PROJECT_ROOT / "scripts" / "pull"
BASELINE_DIR = PROJECT_ROOT / "scripts" / "baseline"
TARGET_DIR = PROJECT_ROOT / "schema-model" / "Tables"

# Files that already exist in schema-model and get overwritten by the pull.
OVERWRITES = ["Customers.Customer.sql"]
# Files that don't exist in schema-model yet and get added by the pull.
ADDITIONS = ["Customers.CustomerPreference.sql"]
# Files that exist in schema-model pre-pull and get deleted by the pull.
DELETIONS = ["Customers.OldFeature.sql", "Customers.SunsetFeature.sql"]


def apply() -> None:
    for name in OVERWRITES + ADDITIONS:
        src = STAGED_DIR / name
        dst = TARGET_DIR / name
        if not src.exists():
            sys.exit(f"missing staged file: {src}")
        shutil.copyfile(src, dst)
        print(f"applied {dst.relative_to(PROJECT_ROOT)}")
    for name in DELETIONS:
        target = TARGET_DIR / name
        if target.exists():
            target.unlink()
            print(f"deleted {target.relative_to(PROJECT_ROOT)}")


def revert() -> None:
    for name in OVERWRITES:
        subprocess.run(
            ["git", "checkout", "--", str((TARGET_DIR / name).relative_to(PROJECT_ROOT))],
            cwd=PROJECT_ROOT,
            check=True,
        )
        print(f"reverted schema-model/Tables/{name}")
    for name in ADDITIONS:
        added = TARGET_DIR / name
        if added.exists():
            added.unlink()
            print(f"removed schema-model/Tables/{name}")
    for name in DELETIONS:
        src = BASELINE_DIR / name
        dst = TARGET_DIR / name
        if not src.exists():
            sys.exit(f"missing baseline file: {src}")
        shutil.copyfile(src, dst)
        print(f"restored schema-model/Tables/{name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revert", action="store_true",
                        help="Restore schema-model to its checked-in state.")
    args = parser.parse_args()
    (revert if args.revert else apply)()


if __name__ == "__main__":
    main()
