# blobspace shape: table of namespaces in the sampled window.
# stdin TSV: label  ns_b64  blobs  bytes  capacity  fee_utia  signers  pfbs   (sorted by bytes, desc)
# vars: net from to got top color

function kind(avg) {
  if (avg < 1024)   return "micro"
  if (avg < 65536)  return "small"
  if (avg < 524288) return "large"
  return "MB-scale"
}
function paint(k, s) {
  if (color != "1") return s
  if (k == "micro")    return "\033[31m" s "\033[0m"
  if (k == "MB-scale") return "\033[33m" s "\033[0m"
  return s
}

BEGIN { FS = "\t" }
{
  n++; lab[n] = $1; blobs[n] = $3; bytes[n] = $4; cap[n] = $5; fee[n] = $6; sig[n] = $7
  T_blobs += $3; T_bytes += $4; T_fee += $6; T_pfbs += $8
}
END {
  printf "\n  celestia %s · blocks %s–%s (%d sampled)\n", net, commas(from), commas(to), got
  printf "  %d namespaces · %s PFBs · %s blobs · %s · %s TIA paid\n\n", n, commas(T_pfbs), commas(T_blobs), hbytes(T_bytes), amount(T_fee / 1e6)
  if (n == 0) { print "  no blobs in this window\n"; exit }
  printf "  %-22s %8s %10s %10s  %-9s %5s %10s %8s\n", "namespace", "blobs", "data", "avg blob", "shape", "pad", "utia/KB", "signers"
  for (i = 1; i <= n && i <= top; i++) {
    avg = bytes[i] / blobs[i]
    k = kind(avg)
    printf "  %-22s %8s %10s %10s  %s %4.0f%% %10.1f %8d\n", \
      substr(lab[i], 1, 22), commas(blobs[i]), hbytes(bytes[i]), hbytes(avg), \
      paint(k, sprintf("%-9s", k)), 100 * (1 - bytes[i] / cap[i]), fee[i] / (bytes[i] / 1000), sig[i]
  }
  if (n > top) printf "  … %d more (raise --top)\n", n - top
  print ""
  print "  pad      share space paid for but left empty: a 13-byte blob still fills a 478-byte share"
  print "  utia/KB  what the namespace actually paid per KB of its own data"
  print ""
}
