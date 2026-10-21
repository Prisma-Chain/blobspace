# Method

How `blobspace` turns blocks into numbers. Everything here is in the scripts. If something below disagrees with the code, the code wins, so please open an issue.

## Where the data comes from

| Data | Source |
|---|---|
| Blob sizes, namespaces, signer | `celestia.blob.v1.EventPayForBlobs` events in CometBFT `/block_results` |
| Fee paid, gas wanted | the `tx` event's `fee` attribute and `gas_wanted` of the same tx result |
| Chain head | `/status` |
| Ethereum base fee, gas limit | `eth_getBlockByNumber("latest")` |
| Ethereum blob base fee | `eth_blobBaseFee` |
| Ethereum priority fee | `eth_maxPriorityFeePerGas` |
| USD prices (quote only, optional) | CoinGecko simple price, `celestia` and `ethereum` |

Only successful transactions (`code == 0`) are counted.

## Shares

Celestia lays blob data out in 512-byte shares. With share version 0:

- the **first** share of a blob holds 478 bytes of data (512 − 29 namespace − 1 info byte − 4 sequence length)
- each **continuation** share holds 482 bytes (512 − 29 − 1)

```
shares(n) = 1                               if n ≤ 478
          = 1 + ceil((n − 478) / 482)       otherwise
capacity(n) = 478 + 482 × (shares(n) − 1)
pad = 1 − n / capacity(n)
```

## PayForBlobs gas

`quote` uses the same estimate as celestia-app's `DefaultEstimateGas` in `x/blob`:

```
gas = 75,000                                  PFBGasFixedCost
    + Σ shares(blob) × 512 × 8                GasPerBlobByte = 8
    + Σ 10 × 70                               TxSizeCostPerByte × BytesPerBlobInfo
```

We checked this against mainnet transactions: clients that use the default estimate set `gas_wanted` to exactly this value (for example 83,892 for an 804-byte blob, and 405,924 for a 69-blob transaction). Clients that simulate first set a lower `gas_wanted` on tiny blobs, so `quote` is the conservative side of what you'd pay. `GAS_PER_BLOB_BYTE` and `TX_SIZE_COST` can be overridden by environment variable if governance changes them.

Payloads above `MAX_PFB_BYTES` (1.9 MB by default) are quoted as several PFBs, one blob each. That adds the fixed cost per PFB, which is under 1% of a large payload.

## Gas price

Median of `fee / gas_wanted` over the PFB transactions in the last 10 blocks. This is the price writers are actually paying, not the node's configured minimum. If those blocks had no PFBs, `quote` falls back to Celenium's `/gas/price` median, or you can pass `--gas-price`.

## Fees per namespace

A transaction pays one fee, but it can carry several blobs in several namespaces. `shape` and `tail` split the fee across the transaction's blobs in proportion to their size, so the per-namespace totals add up to exactly what was paid on-chain.

## Shape classes

By average blob size in the window: `micro` < 1 KB, `small` < 64 KB, `large` < 512 KB, `MB-scale` ≥ 512 KB. `micro` and `MB-scale` are the two extremes the [Blobspace Explorer](https://prismachain.it.com/explorer/celestia/namespace-workbench) highlights in red and amber.

## Namespace labels

The last 10 bytes of the 29-byte namespace. If they decode to printable ASCII (at least 3 characters once zero bytes are removed), they're shown as text. Otherwise they're shown as hex with leading zero bytes trimmed, which matches how Celenium shows IDs.

## The Ethereum comparison

| Lane | Formula |
|---|---|
| Blobs (EIP-4844) | `ceil(bytes / 126,976)` blobs × 131,072 blob gas × blob base fee, plus 21,000 gas × `(base fee + tip)` per transaction of up to 6 blobs |
| Calldata | `(21,000 + 40 × bytes) × (base fee + tip)` |

The calldata lane uses the **EIP-7623 floor** (Pectra): 10 gas per token and 4 tokens per non-zero byte, so 40 gas per byte. Compressed rollup batches are almost entirely non-zero bytes, and floor pricing applies to data-heavy transactions, so this is the realistic rate rather than the older 16 gas per byte.

Not included on either side: the cost of the posting transaction's own execution beyond 21,000 gas, settlement or proof costs, and any batching overhead of a specific rollup stack. The comparison is about moving bytes, not running a rollup.
