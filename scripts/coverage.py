"""Recompute the 2021 compensation figures (appendix A4) from data/wallet_master.csv."""
import csv, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = list(csv.DictReader(open(os.path.join(ROOT, "data/wallet_master.csv"))))


def num(x):
    try:
        return float(x)
    except ValueError:
        return None


measured = [r for r in rows if num(r["coverage_25mar"]) is not None]
print(f"wallets measured: {len(measured)}")
for label, cov, val in (("first 7 days", "coverage_7d", "value_stuck_7d_usd"),
                        ("to 25 March 2021", "coverage_25mar", "value_stuck_25mar_usd")):
    covered = sum(1 for r in measured if num(r[cov]) >= 1)
    short = sum(max(0.0, num(r["stuck_equity_usd_today"]) - num(r[val])) for r in measured)
    print(f"{label:17} >=1.0x: {covered} of {len(measured)}   shortfall ${short:,.0f}")
never = [r for r in measured if r["never_sold"] == "yes"]
print(f"never sold: {len(never)} wallets, frozen equity ${sum(num(r['stuck_equity_usd_today']) for r in never):,.2f}")
