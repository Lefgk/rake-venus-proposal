"""Minimal read-only BSC JSON-RPC helper (eth_call only).
RPC: $BSC_RPC_URL if set; otherwise the BNB public node for the latest block and a public
archive node for a past block (public full nodes keep only recent state)."""
import json, os, urllib.request

RPC = os.environ.get("BSC_RPC_URL")
LATEST_RPC = "https://bsc-dataseed.bnbchain.org"
ARCHIVE_RPC = "https://bsc-mainnet.public.blastapi.io"


def _post(payload, block):
    url = RPC or (LATEST_RPC if block == "latest" else ARCHIVE_RPC)
    req = urllib.request.Request(url, json.dumps(payload).encode(),
                                 {"Content-Type": "application/json", "User-Agent": "rake-verify"})
    return json.load(urllib.request.urlopen(req, timeout=60))


def word(x):
    return (hex(x)[2:] if isinstance(x, int) else x.lower().removeprefix("0x")).rjust(64, "0")


def calls(items, block="latest"):
    """items: [(to, selector, [args])] -> list of result words (list of ints per call)."""
    out = []
    for i in range(0, len(items), 20):  # public nodes reject big batches
        batch = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                  "params": [{"to": to, "data": sel + "".join(word(a) for a in args)}, block]}
                 for j, (to, sel, args) in enumerate(items[i:i + 20])]
        res = sorted(_post(batch, block), key=lambda r: r["id"])
        for r in res:
            if "result" not in r:
                raise SystemExit(f"RPC error at block {block}: {r.get('error')} "
                                 "(a past block needs an archive node in $BSC_RPC_URL)")
            h = r["result"][2:]
            out.append([int(h[k:k + 64], 16) for k in range(0, len(h), 64)])
    return out


def call(to, sel, *args):
    return calls([(to, sel, list(args))])[0]
