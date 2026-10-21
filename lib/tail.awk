# blobspace tail: one line per (tx, namespace).
# stdin TSV: height  label  blobs  bytes  fee_utia  capacity

BEGIN { FS = "\t" }
{
  printf "#%s  %-22s %4d %-5s %10s %10.0f utia %4.0f%% pad\n", \
    $1, substr($2, 1, 22), $3, ($3 == 1 ? "blob" : "blobs"), hbytes($4), $5, 100 * (1 - $4 / $6)
}
