# Celestia share and PayForBlobs gas math.
# Mirrors celestia-app x/blob: DefaultEstimateGas = GasToConsume + TxSizeCostPerByte * BytesPerBlobInfo * blobs + PFBGasFixedCost.

SHARE_SIZE=512
FIRST_SHARE_DATA=478      # 512 - namespace 29 - info byte 1 - sequence length 4
CONT_SHARE_DATA=482       # 512 - namespace 29 - info byte 1
GAS_PER_BLOB_BYTE=${GAS_PER_BLOB_BYTE:-8}
TX_SIZE_COST=${TX_SIZE_COST:-10}
BYTES_PER_BLOB_INFO=70
PFB_FIXED_GAS=75000
MAX_PFB_BYTES=${MAX_PFB_BYTES:-1900000}   # quote splits large payloads into PFBs of this size

# shares_for <blob bytes>
shares_for() {
  local n=$1
  if (( n <= FIRST_SHARE_DATA )); then
    echo 1
  else
    echo $(( 1 + (n - FIRST_SHARE_DATA + CONT_SHARE_DATA - 1) / CONT_SHARE_DATA ))
  fi
}

# pfb_gas <blob bytes>... : gas a PayForBlobs with these blobs is estimated at
pfb_gas() {
  local g=$PFB_FIXED_GAS s
  for s in "$@"; do
    g=$(( g + $(shares_for "$s") * SHARE_SIZE * GAS_PER_BLOB_BYTE + TX_SIZE_COST * BYTES_PER_BLOB_INFO ))
  done
  echo "$g"
}

# ns_label <base64 namespace> : printable 10-byte id if it is text, hex otherwise
ns_label() {
  local txt
  txt=$(printf '%s' "$1" | base64 -d 2>/dev/null | tail -c 10 | tr -d '\000' | LC_ALL=C tr -c '[:print:]' '?')
  if (( ${#txt} >= 3 )) && [[ $txt != *'?'* ]]; then
    printf '%s' "$txt"
  else
    printf '%s' "$1" | base64 -d 2>/dev/null | tail -c 10 | od -An -v -tx1 | tr -d ' \n' | sed 's/^\(00\)*//'
  fi
}
