# coding: utf-8
"""Inspect local source and Git facts; never infer cloud delivery from local state."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {"_build", ".mooncakes", ".git"}


def code_lines(path):
    return sum(1 for line in path.read_text(encoding="utf-8-sig").splitlines()
               if line.strip() and not line.lstrip().startswith("//"))


def git(*args):
    result = subprocess.run(["git", "-C", str(ROOT)] + list(args),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            encoding="utf-8", errors="replace")
    return result.returncode, result.stdout.strip()


def audit():
    production = sorted(p for p in ROOT.glob("*.mbt")
                        if not p.name.endswith(("_test.mbt", "_wbtest.mbt")))
    tests = sorted(p for p in ROOT.rglob("*.mbt")
                   if not EXCLUDED.intersection(p.relative_to(ROOT).parts)
                   and p.name.endswith(("_test.mbt", "_wbtest.mbt")))
    counts = {p.name: code_lines(p) for p in production}
    declarations = sum(len(re.findall(r'(?m)^test "', p.read_text(encoding="utf-8-sig")))
                       for p in tests)
    manifest = (ROOT / "moon.mod").read_text(encoding="utf-8-sig")
    module_match = re.search(r'^name\s*=\s*"([^"\n]+)"', manifest, re.M)
    module = module_match.group(1) if module_match else None
    errors = []
    if sum(counts.values()) < 1500:
        errors.append("Substantive production source is below 1500 lines")
    if not module:
        errors.append("Missing module name")
    if not declarations:
        errors.append("No MoonBit test declarations found")
    required = ["README.md", "LICENSE", "NOTICE", "AI-USE.md", "SECURITY.md",
                ".github/workflows/ci.yml", "docs/competition/duplicate-check.md"]
    errors.extend("Missing file: " + name for name in required if not (ROOT / name).is_file())
    interface = (ROOT / "pkg.generated.mbti").read_text(encoding="utf-8-sig")
    if module and 'package "' + module + '"' not in interface:
        errors.append("Generated root interface does not match manifest module")
    rc, _ = git("rev-parse", "--is-inside-work-tree")
    if rc:
        errors.append("Project is not a Git checkout")
    head_rc, head = git("rev-parse", "--verify", "HEAD")
    if head_rc:
        commit_count = 0
        head = None
    else:
        count_rc, count = git("rev-list", "--count", "HEAD")
        if count_rc:
            errors.append("Could not count reachable Git commits")
        commit_count = int(count) if count_rc == 0 else None
    remote_rc, remotes = git("remote")
    if remote_rc:
        errors.append("Could not inspect Git remote names")
    return {"module": module, "production_lines": counts,
            "production_total": sum(counts.values()), "test_files": len(tests),
            "test_declarations": declarations, "git_commits": commit_count,
            "git_head": head, "git_remote_count": len(remotes.splitlines()) if remotes else 0,
            "delivery_note": "Local Git facts do not establish CI, Release, publication, or official acceptance.",
            "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Emit machine-readable local facts")
    args = parser.parse_args()
    report = audit()
    if args.json:
        print(json.dumps(report, ensure_ascii=True, indent=2))
    else:
        print("Production MoonBit source (nonblank, non-comment physical lines):")
        for name, count in report["production_lines"].items():
            print("  {}: {}".format(name, count))
        print("TOTAL: {}".format(report["production_total"]))
        print("MoonBit test files: {}; test declarations: {}".format(report["test_files"], report["test_declarations"]))
        print("Module: {}; Git commits: {}; remotes: {}".format(report["module"], report["git_commits"], report["git_remote_count"]))
        print(report["delivery_note"])
        for error in report["errors"]:
            print("ERROR: " + error)
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
