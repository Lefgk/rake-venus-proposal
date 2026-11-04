"""Rebuild data/ENTITLEMENTS.csv from RakeFarm and check it: every pool's shares sum to 100%.
Wallets are read from the claim contract's own built-in list. Read-only."""
import csv, os, re, sys
from rpc import calls

FARM = "0x7f7Bf15B9c68D23339C31652C8e860492991760d"
PIDS = range(9, 16)
SYMS = ["BUSD", "BTCB", "ETH", "LINK", "USDT", "USDC", "DOT"]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

src = open(os.path.join(ROOT, "contracts/src/RakeStuckFundsClaim.sol")).read()
body = src[src.index("address[103] memory a = ["):]
wallets = re.findall(r"0x[0-9a-fA-F]{40}", body[:body.index("];")])
assert len(wallets) == 103, len(wallets)

strats = ["0x" + hex(r[4])[2:].rjust(40, "0") for r in calls([(FARM, "0x1526fe27", [p]) for p in PIDS])]
totals = [r[0] for r in calls([(s, "0x44a3955e", []) for s in strats])]
shares = calls([(FARM, "0x93f1a40b", [p, w]) for w in wallets for p in PIDS])

rows, sums = [], [0] * 7
for i, w in enumerate(wallets):
    row = [w]
    for j in range(7):
        s = shares[i * 7 + j][0]
        sums[j] += s
        row.append(f"{s * 100 / totals[j]:.6f}" if s else "")
    rows.append(row)

for j in range(7):
    print(f"{SYMS[j]:5} recorded shares / sharesTotal = {sums[j]}/{totals[j]}", "OK" if sums[j] == totals[j] else "MISMATCH")

out = os.path.join(ROOT, "data/ENTITLEMENTS.csv")
new = [["wallet"] + [f"{s}_pct_of_pool" for s in SYMS]] + rows
if "--write" in sys.argv:
    csv.writer(open(out, "w", newline="")).writerows(new)
    print("wrote", out)
else:
    same = list(csv.reader(open(out))) == new
    print("data/ENTITLEMENTS.csv matches chain" if same else "data/ENTITLEMENTS.csv DIFFERS from chain (run with --write)")
