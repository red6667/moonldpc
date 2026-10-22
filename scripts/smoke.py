"""Run downstream examples and inspect real CLI protocol success and failure."""
import argparse
import json
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--target", choices=["wasm-gc", "wasm", "js", "native"], default="wasm-gc")
args = parser.parse_args()
for name in ["receiver", "designer", "telemetry", "laboratory"]:
    subprocess.run(["moon", "run", "--target", args.target, "examples/"+name], check=True)
code = {"variables": 3, "rows": [[0, 1], [1, 2]]}
for action, payload, expected in [
    ("analyze", {}, True),
    ("exact-decode", {"llr": [-2.0, 0.1, -2.0]}, True),
    ("nearest", {"word": [1, 0, 1]}, True),
    ("stopping", {"variables": [0, 0]}, False),
    ("unknown", {}, False),
]:
    request = dict(payload, action=action, code=code)
    result = subprocess.run(["moon", "run", "--target", args.target, "cmd/main", "--", json.dumps(request)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding="utf-8", check=True)
    response = json.loads(result.stdout)
    if response.get("ok") is not expected:
        raise SystemExit("Unexpected protocol outcome for " + action)
print("Downstream and CLI smoke checks passed for " + args.target)
