# Number formatting shared by the awk reports.

function ceil(x) { return (x == int(x)) ? x : int(x) + 1 }

function commas(n,   s, r) {
  s = sprintf("%.0f", n); r = ""
  while (length(s) > 3) { r = "," substr(s, length(s) - 2) r; s = substr(s, 1, length(s) - 3) }
  return s r
}

function hbytes(n) {
  if (n >= 1e9) return sprintf("%.2f GB", n / 1e9)
  if (n >= 1e6) return sprintf("%.2f MB", n / 1e6)
  if (n >= 1e3) return sprintf("%.1f KB", n / 1e3)
  return sprintf("%d B", n)
}

function amount(x) {
  if (x == 0)      return "0"
  if (x >= 100)    return sprintf("%.1f", x)
  if (x >= 1)      return sprintf("%.3f", x)
  if (x >= 0.0001) return sprintf("%.6f", x)
  return sprintf("%.2e", x)
}

function money(x) {
  if (x == "")   return "-"
  if (x >= 1000) return "$" commas(x)
  if (x >= 0.01) return sprintf("$%.2f", x)
  if (x >= 1e-4) return sprintf("$%.4f", x)
  return sprintf("$%.1e", x)
}

function ratio(a, b) {
  if (a <= 0 || b <= 0) return "n/a"
  if (b >= a) return sprintf("%.1f× cheaper", b / a)
  return sprintf("%.1f× more expensive", a / b)
}
