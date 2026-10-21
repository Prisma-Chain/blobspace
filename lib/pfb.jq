# block_results -> one row per blob:
# {height, tx, ns, size, signer, fee_utia}
# A tx's fee is split across its blobs by size, so per-namespace totals add up to what was paid.
(.result.height | tonumber) as $h
| (.result.txs_results // []) | to_entries[]
| .key as $i | .value as $t
| select(($t.code // 0) == 0)
| [ ($t.events // [])[] | select(.type == "celestia.blob.v1.EventPayForBlobs")
    | .attributes | map({key, value}) | from_entries ] as $pfbs
| select($pfbs | length > 0)
| ([ ($t.events // [])[] | select(.type == "tx") | .attributes[] | select(.key == "fee") | .value ] | first // "0utia"
    | ((capture("^(?<n>[0-9]+)utia") | .n) // "0") | tonumber) as $fee
| [ $pfbs[] | (.signer | fromjson) as $s
    | [ (.namespaces | fromjson), (.blob_sizes | fromjson) ] | transpose[]
    | {ns: .[0], size: .[1], signer: $s} ] as $blobs
| ([ $blobs[].size ] | add) as $total
| $blobs[]
| {height: $h, tx: $i, ns, size, signer, fee_utia: (if $total > 0 then $fee * .size / $total else 0 end)}
