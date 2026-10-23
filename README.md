<img src="https://raw.githubusercontent.com/Prisma-Chain/assets/main/blobspace-banner.svg" width="100%" alt="blobspace: Celestia's data layer, read straight from a node">

**blobspace** is a small command-line tool for anyone who posts data to Celestia, or wants to understand who does. It reads blocks from a Celestia node and answers three questions:

1. **What will this payload cost?** On Celestia, as Ethereum blobs, and as Ethereum calldata, at today's prices.
2. **Who is writing right now, and what does their data look like?** Volume, blob size, wasted share space and the price actually paid, per namespace.
3. **What is landing this second?** Every PayForBlobs as its block is committed.

It needs no API key and no indexer. Everything comes from CometBFT RPC (`/status`, `/block_results`), so you can point it at your own node and trust the numbers as much as you trust that node. It's the command-line companion to Prisma's [Blobspace Explorer](https://prismachain.it.com/explorer/).

```bash
git clone https://github.com/Prisma-Chain/blobspace && cd blobspace
chmod +x blobspace
./blobspace quote 1MB
```

Requires bash 4+, curl, jq 1.6+, awk and coreutils. Works on any Linux box that runs a Celestia node.

---

### `quote`: what a payload costs, in three lanes

```bash
./blobspace quote 250KB
./blobspace quote ./batch-001.bin            # size of a real file
./blobspace quote 8MiB --network mocha --json
```

| Lane | How it's priced |
|---|---|
| **Celestia · blobs** | The exact gas estimate celestia-app uses for a PayForBlobs: shares × 512 × 8 gas, plus per-blob and fixed overhead. Priced at the **median gas price PFB senders paid in the last 10 blocks**, read from the chain. |
| **Ethereum · blobs** | EIP-4844: 131,072 blob gas per blob (126,976 usable bytes), at the live blob base fee, plus a 21,000-gas transaction per 6 blobs. |
| **Ethereum · calldata** | EIP-7623 floor of 40 gas per non-zero byte, which is what compressed rollup data pays since Pectra. Flags payloads too big for one block. |

The last line says how much cheaper or more expensive Celestia is than each Ethereum lane. The answer changes with gas markets, which is why the tool shows the math instead of a headline number.

### `shape`: who is writing, and how

```bash
./blobspace shape                    # last 200 blocks
./blobspace shape --blocks 1000 --top 40
./blobspace shape --json > window.json
```

One row per namespace in the window:

| Column | Meaning |
|---|---|
| `namespace` | The 10-byte namespace ID, shown as text when it is text (`solaxy-sov`), as hex when it isn't |
| `blobs` · `data` | How many blobs and how many bytes it posted |
| `avg blob` · `shape` | Average blob size. 🔴 `micro` under 1 KB · `small` · `large` · 🟡 `MB-scale` from 512 KB |
| `pad` | Share space paid for but left empty |
| `utia/KB` | What it actually paid per KB of its own data, from the tx fees (split across blobs by size) |
| `signers` | Distinct accounts posting to it |

**Why `pad` matters.** Celestia charges by the 512-byte share, not by the byte. A 13-byte blob, which is common for heartbeat and checkpoint posts, still occupies a whole share, so about 97% of what it pays for is padding. Rollups that batch into larger blobs pay a fraction of that per byte. `shape` makes the difference visible per namespace.

### `tail`: blobs as they land

```bash
./blobspace tail
./blobspace tail --network mocha --from 1882700
```

```text
#<height>  <namespace>  <blobs>  <size>  <fee> utia  <pad>% pad
```

Blocks without blobs print as a dim `#height  ·`, so a quiet chain still shows it's alive. If the node drops a request, the tool retries that height and doesn't skip it.

---

### Networks and endpoints

| `--network` | Default RPC | Notes |
|---|---|---|
| `mainnet` | `celestia-rpc.publicnode.com` | Celestia mainnet beta |
| `mocha` | `rpc-mocha.pops.one` | `mocha-5` testnet, where Prisma runs a [validator](https://celestia-dashboard.krews.xyz/celestia-mocha/validators/celestiavaloper1egp30ktgq9805l6es7vs9skl7yt2q7wrj9jc4u) |

Public endpoints rate-limit. For `shape` over large windows, use your own node: `--rpc http://localhost:26657`. Every endpoint can also be set by environment variable: `BLOBSPACE_RPC`, `BLOBSPACE_ETH_RPC`, `BLOBSPACE_NETWORK`. `--no-usd` skips the price lookup, and `NO_COLOR=1` turns off colour.

### How the numbers are computed

Every formula, constant and source is in **[docs/method.md](docs/method.md)**: share layout, the PFB gas estimate, how fees are split across multi-blob transactions, and what the Ethereum comparison does and doesn't include.

---

<sub>Built by [Prisma Chain](https://github.com/Prisma-Chain), a validator built on light · [Blobspace Explorer](https://prismachain.it.com/explorer/) · [prismachain.it.com](https://prismachain.it.com/)</sub>
