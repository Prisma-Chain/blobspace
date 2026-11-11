#!/usr/bin/env bash
# Daily mainnet snapshot, run by .github/workflows/snapshot.yml.
# Writes snapshots/mainnet/<day>.json and refreshes the block between the snapshot markers in README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

day=$(date -u +%F)
out=snapshots/mainnet/$day.json
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p snapshots/mainnet

./blobspace shape --blocks "${BLOCKS:-600}" --json > "$tmp/shape.json"
./blobspace quote 1MB --json > "$tmp/quote.json"

jq -n --arg day "$day" --slurpfile s "$tmp/shape.json" --slurpfile q "$tmp/quote.json" \
  '{day: $day, shape: $s[0], quote_1mb: $q[0]}' > "$out"

jq -r --arg file "$out" '
  def hb: if . >= 1e9 then "\(. / 1e7 | round / 100) GB"
          elif . >= 1e6 then "\(. / 1e4 | round / 100) MB"
          elif . >= 1e3 then "\(. / 1e2 | round / 10) KB"
          else "\(. | round) B" end;
  def usd: if . == null then "–" elif . >= 0.01 then "$\(. * 100 | round / 100)" else "$\(. * 10000 | round / 10000)" end;
  .shape as $s | .quote_1mb as $q
  | "**\(.day) UTC** · mainnet blocks \($s.from)–\($s.to) · \($s.namespaces | length) namespaces · [raw JSON](\($file))",
    "",
    "1 MB right now: Celestia **\($q.celestia.usd | usd)** · Ethereum blobs **\($q.ethereum_blobs.usd | usd)** · Ethereum calldata **\($q.ethereum_calldata.usd | usd)**",
    "",
    "| namespace | data | blobs | avg blob | pad | utia/KB |",
    "|---|--:|--:|--:|--:|--:|",
    ($s.namespaces[:8][]
      | "| `\(.namespace | gsub("[|`]"; "?"))` | \(.bytes | hb) | \(.blobs) | \(.avg_blob | hb) | \(.padding * 100 | round)% | \(.fee_utia / (.bytes / 1000) * 10 | round / 10) |")
' "$out" > "$tmp/block.md"

awk -v f="$tmp/block.md" '
  BEGIN { while ((getline l < f) > 0) b = b l "\n" }
  /<!-- snapshot:start -->/ { print; printf "%s", b; skip = 1; next }
  /<!-- snapshot:end -->/   { skip = 0 }
  !skip
' README.md > "$tmp/README.md"
mv "$tmp/README.md" README.md

echo "wrote $out"
