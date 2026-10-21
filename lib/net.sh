# Endpoints and fetch helpers. Every default can be overridden with a flag or env var.

NETWORK=${BLOBSPACE_NETWORK:-mainnet}
RPC=${BLOBSPACE_RPC:-}
ETH_RPC=${BLOBSPACE_ETH_RPC:-https://ethereum-rpc.publicnode.com}
PRICE_API=${BLOBSPACE_PRICE_API:-https://api.coingecko.com/api/v3/simple/price}
CELENIUM=

die()  { printf 'blobspace: %s\n' "$*" >&2; exit 1; }
need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "needs '$c' on PATH"; done; }

set_network() {
  case $NETWORK in
    mainnet) RPC=${RPC:-https://celestia-rpc.publicnode.com}; CELENIUM=https://api-mainnet.celenium.io/v1 ;;
    mocha)   RPC=${RPC:-https://rpc-mocha.pops.one};          CELENIUM=https://api-mocha.celenium.io/v1 ;;
    *) die "unknown network '$NETWORK' (mainnet | mocha)" ;;
  esac
  RPC=${RPC%/}
}

get()     { curl -fsS --retry 2 --retry-delay 1 --max-time 20 "$1"; }
rpc_get() { get "$RPC/$1"; }

latest_height() {
  rpc_get status | jq -er '.result.sync_info.latest_block_height' || die "can't read status from $RPC"
}

# eth_rpc <method> [params json] : prints .result
eth_rpc() {
  curl -fsS --max-time 20 -H 'content-type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":${2:-[]}}" "$ETH_RPC" | jq -ec '.result'
}

# Gas price that PayForBlobs senders are paying right now: median of fee / gas_wanted
# over the last 10 blocks. Falls back to Celenium, then to the node's own minimum.
celestia_gas_price() {
  if [[ -n ${GAS_PRICE:-} ]]; then echo "$GAS_PRICE"; return; fi
  local top h p
  top=$(latest_height)
  p=$(for h in $(seq $((top - 9)) "$top"); do rpc_get "block_results?height=$h" || true; done \
    | jq -r '.result.txs_results // [] | .[] | select((.code // 0) == 0)
        | select(any(.events[]; .type == "celestia.blob.v1.EventPayForBlobs"))
        | ([.events[] | select(.type == "tx") | .attributes[] | select(.key == "fee") | .value] | first // empty) as $f
        | (($f | capture("^(?<n>[0-9]+)utia") | .n | tonumber) / (.gas_wanted | tonumber))' 2>/dev/null \
    | sort -g | awk '{ a[NR] = $1 } END { if (NR) printf "%.6f\n", a[int((NR + 1) / 2)] }' || true)
  if [[ -z $p ]]; then
    p=$(get "$CELENIUM/gas/price" 2>/dev/null | jq -r '.median // empty' 2>/dev/null || true)
  fi
  [[ -n $p ]] || die "no gas price: no PFBs in the last 10 blocks and Celenium unreachable; pass --gas-price"
  echo "$p"
}

# usd_prices : prints "<tia> <eth>" or nothing
usd_prices() {
  get "$PRICE_API?ids=celestia,ethereum&vs_currencies=usd" 2>/dev/null \
    | jq -r '"\(.celestia.usd // empty) \(.ethereum.usd // empty)"' 2>/dev/null || true
}
