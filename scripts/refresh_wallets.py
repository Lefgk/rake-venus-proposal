"""Re-price data/wallet_master.csv at a block: each wallet's frozen equity (its farm shares ×
each position's net equity at Venus oracle prices) and the coverage ratios that divide by it.
The 2021 RAKE values in the file do not change. Read-only on chain. Usage: refresh_wallets.py <block>"""
import csv, os, sys
from rpc import calls
from figures import positions

FARM = "0x7f7Bf15B9c68D23339C31652C8e860492991760d"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "data/wallet_master.csv")

block = hex(int(sys.argv[1]))
pos = positions(block)
strats = ["0x" + hex(r[4])[2:].rjust(40, "0") for r in calls([(FARM, "0x1526fe27", [p]) for p in range(9, 16)], block)]
totals = [r[0] for r in calls([(s, "0x44a3955e", []) for s in strats], block)]

rows = list(csv.DictReader(open(PATH)))
shares = calls([(FARM, "0x93f1a40b", [p, r["wallet"]]) for r in rows for p in range(9, 16)], block)
for i, r in enumerate(rows):
    eq = sum(shares[i * 7 + j][0] * pos[j][1] / totals[j] / 1e18 * pos[j][2] for j in range(7))
    r["stuck_equity_usd_today"] = f"{eq:.2f}"
    for col, val in (("coverage_7d", "value_stuck_7d_usd"), ("coverage_25mar", "value_stuck_25mar_usd"),
                     ("coverage_actual_sales", "usd_received_25mar")):
        r[col] = f"{float(r[val]) / eq:.4f}" if round(eq, 2) > 0 else ""

w = csv.DictWriter(open(PATH, "w", newline=""), fieldnames=list(rows[0].keys()))
w.writeheader()
w.writerows(rows)
print(f"repriced {len(rows)} wallets at block {int(block, 16)}; total ${sum(float(r['stuck_equity_usd_today']) for r in rows):,.2f}")
