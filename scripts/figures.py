"""Net equity of the seven frozen positions at Venus oracle prices, and the 20/10/70 split.
Net = vToken balance × exchange rate − borrow balance. Read-only. Usage: figures.py [block]"""
import sys
from rpc import calls

COMPTROLLER = "0xfD36E2c2a6789Db23113685031d7F16329158384"
MARKETS = [  # (symbol, vToken, strategy), RakeFarm pids 9–15
    ("BUSD", "0x95c78222B3D6e262426483D42CfA53685A67Ab9D", "0xDF3df3EE9Fb6D5c9B4fdcF80A92D25d2285A859C"),
    ("BTCB", "0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B", "0xB3bCA2C1c2C4DF2C903BE3F341C96732Ac8b3c12"),
    ("ETH", "0xf508fCD89b8bd15579dc79A6827cB4686A3592c8", "0x9E3e8878B53c5762Ec6F461701f02ee6d1D9d19C"),
    ("LINK", "0x650b940a1033B8A1b1873f78730FcFC73ec11f1f", "0x0b09Efc9458c00354414D2A560aA6EDa19490169"),
    ("USDT", "0xfD5840Cd36d94D7229439859C0112a4185BC0255", "0xc6f470dA6C284D16647CEE2230522a85b0818f6D"),
    ("USDC", "0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8", "0x7485704d8B6cEBd1411F5AAfEB063e6f2816069A"),
    ("DOT", "0x1610bc33319e9398de5f57B33a5b184c806aD217", "0x568254EAAC1476faf9A908e577faa3Ab96029801"),
]


def positions(block="latest"):
    """[(symbol, net underlying in wei, USD price per whole token)] — all seven are 18 decimals."""
    oracle = "0x" + hex(calls([(COMPTROLLER, "0x7dc0d1d0", [])], block)[0][0])[2:].rjust(40, "0")
    q = []
    for _, v, s in MARKETS:
        q += [(v, "0x70a08231", [s]), (v, "0x182df0f5", []), (v, "0x95dd9193", [s]), (oracle, "0xfc57d4df", [v])]
    r = [x[0] for x in calls(q, block)]
    return [(sym, r[i * 4] * r[i * 4 + 1] // 10**18 - r[i * 4 + 2], r[i * 4 + 3] / 1e18)
            for i, (sym, _, _) in enumerate(MARKETS)]


if __name__ == "__main__":
    block = hex(int(sys.argv[1])) if len(sys.argv) > 1 else "latest"
    total = 0.0
    for sym, net, px in positions(block):
        usd = net / 1e18 * px
        total += usd
        print(f"{sym:5} net {net / 1e18:>16,.6f}  @ ${px:>12,.6f}  = ${usd:>12,.2f}")
    print(f"TOTAL          ${total:,.2f}")
    print(f"Venus 20%      ${total * .20:,.2f}")
    print(f"Founder 10%    ${total * .10:,.2f}")
    print(f"Depositors 70% ${total * .70:,.2f}")
