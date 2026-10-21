# blobspace quote: one payload, three lanes.
# vars: b sh cg npfb gp net | base tip bf glim (wei, empty if Ethereum is unreachable) | tia eth (USD, may be empty)

BEGIN {
  have_eth = (base != "")
  have_usd = (tia != "" && eth != "")

  c_tia = ceil(cg * gp) / 1e6
  if (have_eth) {
    nblobs   = ceil(b / 126976)                    # 4096 field elements x 31 usable bytes
    blob_gas = nblobs * 131072
    blob_txs = ceil(nblobs / 6)                    # max 6 blobs per tx
    blob_eth = (blob_gas * bf + 21000 * blob_txs * (base + tip)) / 1e18
    cd_gas   = 21000 + 40 * b                      # EIP-7623 floor: 40 gas per non-zero byte
    cd_eth   = cd_gas * (base + tip) / 1e18
    cd_blocks = ceil(cd_gas / glim)
  }
  if (have_usd) { c_usd = c_tia * tia; b_usd = blob_eth * eth; d_usd = cd_eth * eth }

  if (json == "1") {
    printf "{\"bytes\":%.0f,\"network\":\"%s\",\"celestia\":{\"pfbs\":%d,\"shares\":%.0f,\"gas\":%.0f,\"gas_price_utia\":%s,\"fee_tia\":%.6f%s}", \
      b, net, npfb, sh, cg, gp, c_tia, have_usd ? sprintf(",\"usd\":%.6f", c_usd) : ""
    if (have_eth) {
      printf ",\"ethereum_blobs\":{\"blobs\":%d,\"blob_gas\":%.0f,\"blob_base_fee_wei\":%.0f,\"fee_eth\":%.12f%s}", \
        nblobs, blob_gas, bf, blob_eth, have_usd ? sprintf(",\"usd\":%.6f", b_usd) : ""
      printf ",\"ethereum_calldata\":{\"gas\":%.0f,\"blocks\":%d,\"base_fee_wei\":%.0f,\"fee_eth\":%.12f%s}", \
        cd_gas, cd_blocks, base, cd_eth, have_usd ? sprintf(",\"usd\":%.6f", d_usd) : ""
    }
    print "}"
    exit
  }

  printf "\n  %s on celestia %s · gas %s utia\n", hbytes(b), net, gp
  if (have_eth) printf "  ethereum base fee %.3f gwei · blob base fee %.4f gwei\n", base / 1e9, bf / 1e9
  printf "\n  %-22s %-18s %14s %16s %10s\n", "lane", "units", "gas", "fee", "usd"
  printf "  %-22s %-18s %14s %16s %10s\n", "celestia · blobs", commas(sh) " shares", commas(cg), amount(c_tia) " TIA", have_usd ? money(c_usd) : "-"
  if (have_eth) {
    printf "  %-22s %-18s %14s %16s %10s\n", "ethereum · blobs", commas(nblobs) (nblobs == 1 ? " blob" : " blobs"), commas(blob_gas), amount(blob_eth) " ETH", have_usd ? money(b_usd) : "-"
    printf "  %-22s %-18s %14s %16s %10s\n", "ethereum · calldata", hbytes(b), commas(cd_gas), amount(cd_eth) " ETH", have_usd ? money(d_usd) : "-"
    if (cd_blocks > 1) printf "  %-22s calldata needs %d full blocks at the current gas limit\n", "", cd_blocks
  } else {
    print "  (ethereum rpc unreachable, celestia only)"
  }
  if (have_usd && have_eth)
    printf "\n  celestia is %s than ethereum blobs, %s than calldata\n", ratio(c_usd, b_usd), ratio(c_usd, d_usd)
  print ""
}
