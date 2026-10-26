"""Offline, independent GF(2) verification of the fixed IEEE 802.11 profile.
Optional --reference-dir checks pinned upstream bytes and reruns their encoder.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--reference-dir", type=Path)
args = parser.parse_args()
d = json.loads((root / "tests/fixtures/wifi1944-r34.json").read_text(encoding="utf-8"))
n, k, z = d["n"], d["k"], d["z"]
assert (n, k, z) == (1944, 1458, 81)
base = d["base"]
assert len(base) == 6 and all(len(row) == 24 for row in base)
assert all(-1 <= s < z for row in base for s in row)
source = (root / "wifi.mbt").read_text(encoding="utf-8")
body = source.split("fn wifi_1944_r34_base()", 1)[1].split("///|", 1)[0]
body = body[body.index("{") + 1:]
assert list(map(int, re.findall(r"-?\d+", body))) == [s for row in base for s in row]
rows = [[c*z+(r%z+s)%z for c,s in enumerate(base[r//z]) if s >= 0] for r in range(n-k)]
# Independent bit-packed elimination of the 486 x 486 parity submatrix.
# The MoonBit encoder instead uses its sparse staircase; no formula is shared.
parity = [sum(1 << (c-k) for c in row if c >= k) for row in rows]
transforms = [1 << i for i in range(n-k)]
for col in range(n-k):
    pivot = next(i for i in range(col,n-k) if (parity[i] >> col) & 1)
    parity[col],parity[pivot] = parity[pivot],parity[col]
    transforms[col],transforms[pivot] = transforms[pivot],transforms[col]
    for i in range(n-k):
        if i != col and (parity[i] >> col) & 1:
            parity[i] ^= parity[col]
            transforms[i] ^= transforms[col]
assert parity == [1 << i for i in range(n-k)]
moon_tests = (root / "wifi_reference_test.mbt").read_text(encoding="utf-8")
for case in d["cases"]:
    a,b = case["input"],case["expected"]
    assert len(a)==k and len(b)==n and set(a+b) <= {"0","1"}
    assert b[:k] == a
    rhs = sum((sum(int(a[c]) for c in row if c < k)%2) << i for i,row in enumerate(rows))
    solved = a + "".join(str(bin(t & rhs).count("1")%2) for t in transforms)
    assert solved == b, case["name"]
    assert all(sum(int(b[c]) for c in row)%2 == 0 for row in rows)
    assert '"'+a+'"' in moon_tests and '"'+b+'"' in moon_tests
annex=d["cases"][0]
assert annex["name"] == "annex-g-example-1"
assert annex["input"][816:] == "0"*642
assert annex["expected"][:816]+annex["expected"][1458:1890] == d["annex_final_bits"]
assert len(d["annex_final_bits"]) == 1248
assert '"'+d["annex_final_bits"]+'"' in moon_tests
if args.reference_dir:
    for item in d["sources"]:
        raw=(args.reference_dir/item["local_file"]).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == item["sha256"], item["path"]
    h=(args.reference_dir/"independent-WiFiLDPC.h").read_text(encoding="utf-8")
    block=re.search(r"H_1944_3_4\s*\[6\]\[24\]\s*=\s*\{(.*?)\};",h,re.S).group(1)
    assert list(map(int,re.findall(r"-?\d+",block))) == [s for row in base for s in row]
    result=subprocess.check_output(["node",str(root/"scripts/wifi_reference.cjs"),str(args.reference_dir)],encoding="utf-8")
    external=json.loads(result)
    assert external["base"]==base
    for actual,want in zip(external["cases"],d["cases"]):
        assert actual["name"]==want["name"]
        assert "".join(map(str,actual["input"]))==want["input"]
        assert "".join(map(str,actual["expected"]))==want["expected"]
    assert len(external["cases"]) == len(d["cases"])
    assert "".join(map(str,external["annex_final_bits"])) == d["annex_final_bits"]
    print("Pinned source hashes, second upstream matrix and external encoder: PASS")
print("Independent GF(2), 7 complete vectors, 486 matrix rows, embedded fixtures and Annex G rate selection: PASS")
