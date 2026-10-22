# coding: utf-8
"""Verify an explicitly reviewed commit ledger; do not infer merit from raw count."""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], encoding="utf-8").strip()

def validate(records, facts, login):
    errors, accepted, seen = [], [], set()
    for record in records:
        sha = record.get("sha", "")
        if not re.fullmatch(r"[0-9a-f]{40}", sha) or sha in seen:
            errors.append("Malformed or duplicated ledger SHA")
            continue
        seen.add(sha)
        fact = facts.get(sha)
        if not fact:
            errors.append("Ledger SHA not reachable: " + sha)
            continue
        if not fact["paths"] or fact["parents"] > 1:
            errors.append("Empty or merge commit cannot be a reviewed slice: " + sha)
            continue
        if fact["author"] != login or fact["committer"] != login:
            errors.append("Commit identity mismatch: " + sha)
            continue
        if not record.get("purpose", "").strip() or not record.get("verification", "").strip():
            errors.append("Missing purpose or verification: " + sha)
            continue
        accepted.append(dict(record, paths=fact["paths"]))
    return accepted, errors

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=ROOT / "docs/competition/engineering-slices.json")
    parser.add_argument("--min-reviewed", type=int, default=20)
    parser.add_argument("--login", default="red6667")
    args = parser.parse_args()
    if not args.ledger.is_file():
        parser.error("Reviewed ledger does not exist")
    records = json.loads(args.ledger.read_text(encoding="utf-8-sig"))
    facts = {}
    for sha in git("rev-list", "--reverse", "HEAD").splitlines():
        fields = git("show", "-s", "--format=%an%n%cn%n%P", sha).splitlines()
        facts[sha] = {"author": fields[0], "committer": fields[1],
                      "parents": len(fields[2].split()) if len(fields) > 2 else 0,
                      "paths": git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", sha).splitlines()}
    accepted, errors = validate(records, facts, args.login)
    if len(accepted) < args.min_reviewed:
        errors.append("Reviewed engineering slices below required floor")
    print(json.dumps({"raw_commits": len(facts), "reviewed_commits": len(accepted),
                      "note": "Merit and verification are explicit reviewer assertions, not inferred from count.",
                      "commits": accepted, "errors": errors}, indent=2))
    return 1 if errors else 0

if __name__ == "__main__":
    raise SystemExit(main())
